_addon.name = 'WhereIsNM'
_addon.author = 'Mandracord Team'
_addon.version = '1.0.1'
_addon.commands = {'nm', 'whereisnm'}

------------------------------------------------------------------------------------------------------------------------
-- Importing modules
------------------------------------------------------------------------------------------------------------------------

require('luau')

-- Modules
local Queue = require('util.queue')
local Scanner = require('util.scanner')
local Settings = require('util.settings')
local Logger = require('util.logger')
local TodTracker = require('util.tod_tracker')
local Api = require('util.api')
local Commands = require('util.commands')
local FloorDetector = require('util.floor_detector')
local CaptureConditions = require('util.capture_conditions')

-- Variables
local INITIAL_SCAN_DELAY = 15
local SCAN_LOOP_INTERVAL = 12

------------------------------------------------------------------------------------------------------------------------
--[[
------------------------------------------------------------------------------------------------------------------------
CREDITS | SPECIAL THANKS | ACKNOWLEDGE
------------------------------------------------------------------------------------------------------------------------

A big THANK YOU to the following people for some logic and inspiration:

NAME                 URL
AkadenTK             https://github.com/AkadenTK/superwarp
Aphung               https://github.com/aphung/whereisdi

A special thank you to the Windower project for your hard work and dedication.
And, YOU - thank you for using WhereIsNM, we hope it will useful in your hunt for NMs and ??? inside Limbus.

------------------------------------------------------------------------------------------------------------------------

RELEASE NOTES
See all release notes on https://whereisnm.com/release-notes 

------------------------------------------------------------------------------------------------------------------------
]]

------------------------------------------------------------------------------------------------------------------------
-- !! DO NOT EDIT BELOW !!
------------------------------------------------------------------------------------------------------------------------

local settings_defaults = Settings.get_defaults and Settings.get_defaults() or {}
local settings, displaybox = Settings.load()
local logger = Logger.new({
    enabled = settings.debug,
    file_path = 'data/debug.txt'
})

local function current_settings()
    return Settings.get() or settings
end

local function send_enabled()
    local active_settings = current_settings()
    return active_settings and active_settings.send
end

local function submit_on_zone_change_enabled()
    local active_settings = current_settings()
    local value = active_settings and active_settings.submit_on_zone_change
    if value == nil then
        return true
    end
    return value
end

local function submit_on_floor_change_enabled()
    local active_settings = current_settings()
    local value = active_settings and active_settings.submit_on_floor_change
    if value == nil then
        return true
    end
    return value
end

local function debug_enabled()
    local active_settings = current_settings()
    return active_settings and active_settings.debug
end

local function configured_batch_report_limit()
    local active_settings = current_settings()
    return (active_settings and active_settings.batch_report_limit) or settings_defaults.batch_report_limit or 3
end

local function configured_batch_flush_interval()
    local active_settings = current_settings()
    return (active_settings and active_settings.batch_flush_interval) or settings_defaults.batch_flush_interval or 3600
end

local function get_batch_limit(opts)
    if opts and opts.limit then
        return opts.limit
    end
    return configured_batch_report_limit()
end

local function batch_mode_enabled()
    local active_settings = current_settings()
    return active_settings and active_settings.submit_batch_mode == true
end

local function objective_reporting_enabled()
    local active_settings = current_settings()
    if not active_settings then
        return false
    end

    if not active_settings.send then
        return false
    end

    return active_settings.capture_objectives == true
end

local function total_pending_reports()
    local total = Queue.get_spawn_queue_count() + Queue.get_tod_queue_count()
    if Queue.get_objective_queue_count then
        total = total + Queue.get_objective_queue_count()
    end
    return total
end

local floor_detector
local objective_conditions
local scan_loop_active = false

local handle_pending_reports

local floor_scan_pending = false
local function request_floor_scan(attempt, is_retry)
    attempt = attempt or 1

    if floor_scan_pending and not is_retry then
        return
    end

    local settings = current_settings()

    if not send_enabled() then
        return
    end

    local zone_info = windower.ffxi.get_info()
    local zone_id = zone_info and zone_info.zone
    if not zone_id or not Scanner.is_limbus_zone(zone_id) then
        return
    end

    floor_scan_pending = true

    if debug_enabled() then
        if attempt == 1 then
            logger:log('Scheduling scan due to floor change')
        else
            logger:log(string.format('Retrying scan (attempt %d)', attempt))
        end
    end

    local delay = (attempt == 1) and 1 or math.min(3, 0.75 * attempt)

    coroutine.schedule(function()
        floor_scan_pending = false

        if not send_enabled() then
            return
        end

        local info = windower.ffxi.get_info()
        local current_zone = info and info.zone
        if current_zone and Scanner.is_limbus_zone(current_zone) then
            local context = floor_detector and floor_detector.get_floor_context and floor_detector:get_floor_context()

            if not context then
                if debug_enabled() then
                    logger:log('Scan skipped: floor context still unavailable')
                end
                if attempt < 4 then
                    request_floor_scan(attempt + 1, true)
                end
                return
            end

            Scanner.set_floor_context(context)

            if context.tower == 'entrance' then
                if debug_enabled() then
                    logger:log('Scan skipped: entrance floor detected')
                end
                if send_enabled() then
                    handle_pending_reports({trigger = 'floor', limit = configured_batch_report_limit()})
                end
                return
            end

            Scanner.trigger_scan()
            if not scan_loop_active then
                if debug_enabled() then
                    logger:log('Scan loop started')
                end
                scan_loop_active = true
                local function loop()
                    if not scan_loop_active then
                        return
                    end

                    if not send_enabled() then
                        coroutine.schedule(loop, SCAN_LOOP_INTERVAL)
                        return
                    end

                    local info_loop = windower.ffxi.get_info()
                    local zone_loop = info_loop and info_loop.zone
                    if not zone_loop or not Scanner.is_limbus_zone(zone_loop) then
                        scan_loop_active = false
                        if debug_enabled() then
                            logger:log('Scan loop stopped (left Limbus)')
                        end
                        return
                    end

                    local loop_context = floor_detector and floor_detector:get_floor_context()
                    if loop_context then
                        if loop_context.tower == 'entrance' then
                            if debug_enabled() then
                                logger:log('Scan loop paused: entrance floor detected')
                            end
                            if send_enabled() then
                                handle_pending_reports({trigger = 'floor', limit = configured_batch_report_limit()})
                            end
                        else
                            Scanner.set_floor_context(loop_context)
                            Scanner.trigger_scan()
                        end
                    elseif debug_enabled() then
                        logger:log('Scan loop skipped: floor context unavailable')
                    end

                    coroutine.schedule(loop, SCAN_LOOP_INTERVAL)
                end

                coroutine.schedule(loop, SCAN_LOOP_INTERVAL)
            end
        end
    end, delay)
end

local tod_tracker = TodTracker.new(Scanner, Queue, {
    logger = logger,
    debug_enabled = debug_enabled,
    chat_prefix = string.format('[%s]', _addon.name),
    chat_color = 123
})

local api = Api.new({
    logger = logger,
    debug_enabled = debug_enabled,
    base_url = settings.api_base_url,
    include_expired_provider = function()
        local active_settings = current_settings()
        return active_settings and active_settings.include_dead == true
    end,
})

Queue.set_api(api)

handle_pending_reports = function(opts)
    opts = opts or {}

    if not send_enabled() then
        return
    end

    local trigger = opts.trigger or 'manual'
    local force_send = opts.force == true

    local pending_spawn = Queue.get_spawn_queue_count()
    local pending_tod = Queue.get_tod_queue_count()
    local include_objectives = objective_reporting_enabled()
    local pending_objectives = include_objectives and Queue.get_objective_queue_count
        and Queue.get_objective_queue_count() or 0

    local total_pending = pending_spawn + pending_tod + pending_objectives
    if total_pending == 0 then
        return
    end

    local batching = batch_mode_enabled()
    local should_batch = batching and not force_send and trigger ~= 'zone'
    local batch_limit = get_batch_limit(opts)
    local spawn_to_send = pending_spawn
    local tod_to_send = pending_tod
    local objective_to_send = pending_objectives

    if should_batch then
        if not batch_limit or batch_limit < 1 then
            windower.add_to_chat(123,
                string.format('[%s] Batch mode holding all pending reports (spawn=%d, tod=%d, objectives=%d).',
                    _addon.name, pending_spawn, pending_tod, pending_objectives))
            return
        end

        local remaining = math.min(batch_limit, total_pending)
        tod_to_send = math.min(pending_tod, remaining)
        remaining = remaining - tod_to_send

        spawn_to_send = 0
        objective_to_send = 0

        local spawn_used = 0
        local objective_used = 0

        local function spawn_available()
            return pending_spawn - spawn_used
        end

        local function objective_available()
            return pending_objectives - objective_used
        end

        local spawn_turn = true
        while remaining > 0 do
            local spawn_left = spawn_available()
            local objective_left = objective_available()
            if spawn_left <= 0 and objective_left <= 0 then
                break
            end

            if spawn_turn and spawn_left > 0 then
                spawn_used = spawn_used + 1
                spawn_to_send = spawn_used
                remaining = remaining - 1
            elseif not spawn_turn and objective_left > 0 then
                objective_used = objective_used + 1
                objective_to_send = objective_used
                remaining = remaining - 1
            else
                if spawn_left > 0 then
                    spawn_used = spawn_used + 1
                    spawn_to_send = spawn_used
                    remaining = remaining - 1
                elseif objective_left > 0 then
                    objective_used = objective_used + 1
                    objective_to_send = objective_used
                    remaining = remaining - 1
                end
            end

            spawn_turn = not spawn_turn
        end

        if (spawn_to_send + tod_to_send + objective_to_send) == 0 then
            windower.add_to_chat(123,
                string.format('[%s] Batch mode holding %d spawn, %d TOD, %d objectives.', _addon.name,
                    pending_spawn, pending_tod, pending_objectives))
            if debug_enabled() then
                logger:log(string.format(
                    'Batch mode deferring %d spawn, %d TOD, %d objectives (trigger=%s)', pending_spawn, pending_tod,
                    pending_objectives, trigger))
            end
            return
        end
    end

    local total_to_send = spawn_to_send + tod_to_send + objective_to_send
    if total_to_send == 0 then
        return
    end

    local objective_label = ''
    if objective_to_send > 0 then
        objective_label = string.format(', %d objectives', objective_to_send)
    end

    windower.add_to_chat(123,
        string.format('[%s] Sending %d pending reports (%d spawn, %d TOD%s).', _addon.name, total_to_send,
            spawn_to_send, tod_to_send, objective_label))

    if debug_enabled() then
        logger:log(string.format('Sending %d pending reports (%d spawn, %d TOD%s) [trigger=%s, batch=%s]',
            total_to_send, spawn_to_send, tod_to_send, objective_label, trigger, tostring(should_batch)))
    end

    Queue.send_queued_reports({
        announce = true,
        include_spawn = spawn_to_send > 0,
        include_tod = tod_to_send > 0,
        include_objectives = objective_to_send > 0,
        spawn_limit = should_batch and spawn_to_send or nil,
        tod_limit = should_batch and tod_to_send or nil,
        objective_limit = should_batch and objective_to_send or nil,
    })
end

local last_scan_summary

local function capitalize_label(text)
    if not text or text == '' then
        return ''
    end
    return text:sub(1, 1):upper() .. text:sub(2)
end

local function build_scan_summary(area, results)
    local summary = {
        area = area,
        nm = {},
        question = {},
    }

    if results then
        for _, entry in ipairs(results) do
            local tower = entry.tower and entry.tower:upper() or '?'
            local floor = entry.floor or 0
            local location = string.format('%s F%d', tower, floor)

            if entry.spawn_type == 'nm' then
                summary.nm[#summary.nm + 1] = string.format('%s - %s', location, entry.mob_name or 'Unknown')
            else
                summary.question[#summary.question + 1] = location
            end
        end
    end

    table.sort(summary.nm)
    table.sort(summary.question)

    return summary
end

local function print_scan_summary(summary)
    if not summary then
        if debug_enabled() then 
            windower.add_to_chat(123, '[WhereIsNM] No scan results available yet.')
        end
        return
    end

    local total = (#summary.nm) + (#summary.question)
    if total == 0 then
        windower.add_to_chat(123, '[WhereIsNM] No NMs or ??? found in this area.')
        return
    end

    local area_name = capitalize_label(summary.area or 'unknown area')

    if debug_enabled() then
        windower.add_to_chat(123, string.format('[WhereIsNM] Scan Result (%s)', area_name))
    end

    if #summary.nm > 0 then
        if debug_enabled() then
            windower.add_to_chat(123, 'NM:')
            for _, line in ipairs(summary.nm) do
                windower.add_to_chat(123, string.format('  - %s', line))
            end
        end
    end

    if #summary.question > 0 then
        if debug_enabled() then
            windower.add_to_chat(123, '??? :')
            for _, line in ipairs(summary.question) do
                windower.add_to_chat(123, string.format('  - %s', line))
            end
        end
    end
end

floor_detector = FloorDetector.new({
    logger = logger,
    debug_enabled = debug_enabled,
    handle_reports = function(trigger)
        if trigger == 'floor' then
            request_floor_scan()
        end

        if trigger == 'floor' and not submit_on_floor_change_enabled() then
            return
        end
        if not send_enabled() then
            return
        end
        handle_pending_reports({trigger = trigger, limit = configured_batch_report_limit()})
    end,
    announce = function(message)
        if submit_on_floor_change_enabled() then
            windower.add_to_chat(123, message)
        end
    end,
})
floor_detector:reset()

objective_conditions = CaptureConditions.new({
    logger = logger,
    api = api,
    enabled_provider = objective_reporting_enabled,
    debug_enabled_provider = debug_enabled,
    area_context_provider = function()
        if not floor_detector or not floor_detector.get_floor_context then
            return nil
        end
        return floor_detector:get_floor_context()
    end,
    batch_enabled_provider = batch_mode_enabled,
    queue_handler = function(payload)
        return Queue.queue_objective_report(payload)
    end,
})

local function schedule_batch_flush()
    coroutine.schedule(function()
        if batch_mode_enabled() then
            handle_pending_reports({trigger = 'timer', limit = configured_batch_report_limit()})
        end
        schedule_batch_flush()
    end, configured_batch_flush_interval())
end

schedule_batch_flush()

Scanner.set_scan_complete_callback(function(results)
    if not send_enabled() then
        return
    end

    if not submit_on_zone_change_enabled() and not submit_on_floor_change_enabled() then
        return
    end

    local zone_info = windower.ffxi.get_info()
    local zone_id = zone_info and zone_info.zone
    local area

    if zone_id == 37 then
        area = 'temenos'
    elseif zone_id == 38 then
        area = 'apollyon'
    elseif results[1] and results[1].area then
        area = results[1].area
    end

    if not area then
        return
    end

    local reports_payload = {}
    if results then
        for _, entry in ipairs(results) do
            reports_payload[#reports_payload + 1] = {
                tower = entry.tower,
                floor = entry.floor,
                spawnType = entry.spawn_type,
                enemyInput = entry.mob_name,
            }
        end
    end

    local observed_count = #reports_payload

    last_scan_summary = build_scan_summary(area, results)
    if (#reports_payload > 0) then
        print_scan_summary(last_scan_summary)
    end

end)

if displaybox and settings and settings.hud == false and displaybox.hide then
    displaybox:hide()
end

Scanner.set_nm_detected_callback(function(nm_data)
    if not nm_data then
        return
    end
    tod_tracker:add_nm(nm_data)
end)

tod_tracker:start()

------------------------------------------------------------------------------------------------------------------------
-- Register Events
------------------------------------------------------------------------------------------------------------------------

windower.register_event('load', 'login', function()
    if not windower.ffxi.get_info().logged_in then
        return
    end

    windower.add_to_chat(123, string.format('[%s] Loaded. Use //nm help for commands.', _addon.name))
    if debug_enabled() then
        logger:log('Addon loaded')
    end

    Queue.load_queue()

    local _, version_message = api:check_version(_addon.version)
    if version_message then
        windower.add_to_chat(123, string.format('[%s] %s', _addon.name, version_message))
        if debug_enabled() then
            logger:log('Version check: ' .. version_message)
        end
    end

    if send_enabled() then
        handle_pending_reports({trigger = 'load', limit = configured_batch_report_limit()})
        local info = windower.ffxi.get_info()
        local zone_id = info and info.zone
        if zone_id and Scanner.is_limbus_zone(zone_id) then
            if debug_enabled() then
                logger:log(string.format('Scheduling scan in %d seconds (load)', INITIAL_SCAN_DELAY))
            end
            coroutine.schedule(function()
                if not send_enabled() then
                    return
                end
                if debug_enabled() then
                    logger:log('Triggering scan now (load)')
                end
                Scanner.trigger_scan()
            end, INITIAL_SCAN_DELAY)
        else
            Scanner.trigger_scan()
        end
    end
end)

windower.register_event('zone change', function(new_zone_id, prev_zone_id)
    if debug_enabled() then
        logger:log(string.format('Zone change: %s -> %s', prev_zone_id or 'nil', new_zone_id))
    end

    if new_zone_id == 37 or new_zone_id == 38 or prev_zone_id == 37 or prev_zone_id == 38 then
        floor_detector:reset()
        Scanner.set_floor_context(nil)
    end

    if not Scanner.is_limbus_zone(new_zone_id) and scan_loop_active then
        scan_loop_active = false
        if debug_enabled() then
            logger:log('Scan loop stopped (zone change)')
        end
    end

    if prev_zone_id and (prev_zone_id == 37 or prev_zone_id == 38) then
        if send_enabled() and submit_on_zone_change_enabled() and total_pending_reports() > 0 then
            handle_pending_reports({trigger = 'zone', force = true})
        end
    end

    if not tod_tracker:on_zone_change(new_zone_id) then
        return
    end

    if send_enabled() then
        if debug_enabled() then
            logger:log(string.format('Scheduling scan in %d seconds', INITIAL_SCAN_DELAY))
        end
        coroutine.schedule(function()
            if not send_enabled() then
                return
            end
            if debug_enabled() then
                logger:log('Triggering scan now')
            end
            Scanner.trigger_scan()
        end, INITIAL_SCAN_DELAY)
    end
end)


windower.register_event('incoming chunk', function(packet_id, original, modified, is_injected, is_blocked)
    if packet_id == 0x075 then
        floor_detector:detect_by_status(original)
    elseif packet_id == 0x052 and not is_injected then
        floor_detector:detect_by_menu(original)
    elseif packet_id == 0x00D and not is_injected then
        floor_detector:detect_by_position()
    end
end)

windower.register_event('incoming chunk', function(packet_id, packet_data)
    if packet_id ~= 0x00E then
        return
    end

    Scanner.process_entity_packet(packet_data)
end)

windower.register_event('incoming chunk', function(packet_id, packet_data)
    if not objective_conditions or not objective_reporting_enabled() then
        return
    end
    objective_conditions:handle_incoming_chunk(packet_id, packet_data)
end)

windower.register_event('incoming text', function(original, modified, mode)
    if not objective_conditions or not objective_reporting_enabled() then
        return
    end
    objective_conditions:handle_incoming_text(original, mode)
end)

------------------------------------------------------------------------------------------------------------------------
-- Command Handler
------------------------------------------------------------------------------------------------------------------------

windower.register_event('addon command', function(command, ...)
    local args = L {...}
        Commands.handle_addon_command(command, args, {
            displaybox = displaybox,
            settings = settings,
            logger = logger,
            api = api,
            scanner = Scanner,
            queue = Queue,
            settings_file = Settings,
            debug_enabled = debug_enabled,
            handle_pending_reports = handle_pending_reports,
            capture_pending = function()
                if not capture_conditions then
                    return false
                end
                return capture_conditions:has_pending_state()
            end,
        })
end)
