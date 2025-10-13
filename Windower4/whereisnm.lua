_addon.name = 'WhereIsNM'
_addon.author = 'Mandracord Team'
_addon.version = '0.0.10-BETA'
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

-- Variables
local SCAN_DELAY = 15

------------------------------------------------------------------------------------------------------------------------
--[[
------------------------------------------------------------------------------------------------------------------------
CREDITS | SPECIAL THANKS | ACKNOWLEDGE
------------------------------------------------------------------------------------------------------------------------

A big THANK YOU to the following people for some logic and inspiration:

NAME                 URL
Seth Van Heulen      https://codeberg.org/svanheulen 
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
-- DO NOT EDIT BELOW
------------------------------------------------------------------------------------------------------------------------

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

local function total_pending_reports()
    return Queue.get_spawn_queue_count() + Queue.get_tod_queue_count()
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

local function handle_pending_reports()
    local pending_spawn = Queue.get_spawn_queue_count()
    local pending_tod = Queue.get_tod_queue_count()
    local total_pending = pending_spawn + pending_tod

    if total_pending > 0 then
        windower.add_to_chat(123,
            string.format('[%s] %d loaded pending reports (%d spawn, %d TOD).', _addon.name, total_pending,
                pending_spawn, pending_tod))
        windower.add_to_chat(123, string.format('[%s] Sending %d pending reports...', _addon.name, total_pending))

        if debug_enabled() then
            logger:log(string.format('Loading %d pending reports (%d spawn, %d TOD)', total_pending, pending_spawn,
                pending_tod))
        end

        Queue.send_queued_reports({announce = true})
    end
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

local floor_detector = FloorDetector.new({
    logger = logger,
    debug_enabled = debug_enabled,
    handle_reports = function(trigger)
        if trigger == 'floor' and not submit_on_floor_change_enabled() then
            return
        end
        if not send_enabled() then
            return
        end
        handle_pending_reports()
    end,
    announce = function(message)
        if submit_on_floor_change_enabled() then
            windower.add_to_chat(123, message)
        end
    end,
})
floor_detector:reset()

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

    if not area or not api or not api.sync_reports then
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
    local ok, status_code, response_text = api:sync_reports({
        area = area,
        reports = reports_payload,
        observed_count = observed_count,
        empty_snapshot = observed_count == 0,
    })

    if not ok and debug_enabled() then
        local message = string.format('Sync failed (%s): %s', tostring(status_code), tostring(response_text))
        logger:log(message)
    elseif ok and debug_enabled() then
        logger:log(string.format('Sync submitted: %d reports for %s', #reports_payload, area))
    end

    last_scan_summary = build_scan_summary(area, results)
    if (#reports_payload > 0) then
        print_scan_summary(last_scan_summary)
    end
end)

if displaybox and settings and settings.hud == false and displaybox.hide then
    displaybox:hide()
end

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
        handle_pending_reports()
        local info = windower.ffxi.get_info()
        local zone_id = info and info.zone
        if zone_id and Scanner.is_limbus_zone(zone_id) then
            if debug_enabled() then
                logger:log(string.format('Scheduling scan in %d seconds (load)', SCAN_DELAY))
            end
            coroutine.schedule(function()
                if not send_enabled() then
                    return
                end
                if debug_enabled() then
                    logger:log('Triggering scan now (load)')
                end
                Scanner.trigger_scan()
            end, SCAN_DELAY)
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
    end

    if prev_zone_id and (prev_zone_id == 37 or prev_zone_id == 38) then
        if send_enabled() and submit_on_zone_change_enabled() and total_pending_reports() > 0 then
            windower.add_to_chat(123, string.format('[%s] Sending pending reports...', _addon.name))
            if debug_enabled() then
                logger:log('Sending pending reports on zone change')
            end

            Queue.send_queued_reports({announce = true})
        end
    end

    if not tod_tracker:on_zone_change(new_zone_id) then
        return
    end

    if send_enabled() then
        if debug_enabled() then
            logger:log(string.format('Scheduling scan in %d seconds', SCAN_DELAY))
        end
        coroutine.schedule(function()
            if not send_enabled() then
                return
            end
            if debug_enabled() then
                logger:log('Triggering scan now')
            end
            Scanner.trigger_scan()
        end, SCAN_DELAY)
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

    local nm_data = Scanner.process_entity_packet(packet_data)

    if nm_data then
        tod_tracker:add_nm(nm_data)
    end
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
        })
end)
