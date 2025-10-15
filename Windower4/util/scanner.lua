require('luau')
local bit = require('bit')
local queue = require('util.queue')
local settingsFile = require('util.settings')
local scanner_data = require('util.scanner_data')
local mob_scanner = require('util.mob_scanner')

local M = {}
local floor_context = nil

local function current_settings()
    return settingsFile.get()
end

local function debug_enabled()
    local settings = current_settings()
    return settings and settings.debug
end

local scanned_entities = {}
local scan_active = false
local scan_results = {}
local scan_complete_callback
local nm_detected_callback

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

---@alias RegisterEntityFn fun(zone_id: number, mob_name: string, position: table, mob_id: number|nil): table|nil

local function reset_scan_state(zone_id)
    if not scanner_data.ENTITY_NAMES[zone_id] then return end
    
    for entity_name, _ in pairs(scanner_data.ENTITY_NAMES[zone_id]) do
        scanned_entities[entity_name] = nil
    end

    scan_results = {}
end

local function clone_scan_results()
    local copy = {}
    for index, entry in ipairs(scan_results) do
        copy[index] = {
            area = entry.area,
            tower = entry.tower,
            floor = entry.floor,
            spawn_type = entry.spawn_type,
            mob_name = entry.mob_name,
        }
    end
    return copy
end

local function dispatch_scan_complete()
    if not scan_complete_callback then
        return
    end

    local ok, err = pcall(scan_complete_callback, clone_scan_results())
    if not ok and debug_enabled() then
        windower.add_to_chat(123, string.format('[WhereIsNM] error: %s', tostring(err)))
    end
end

local function dispatch_nm_detected(nm_data)
    if not nm_detected_callback or not nm_data then
        return
    end

    local ok, err = pcall(nm_detected_callback, nm_data)
    if not ok and debug_enabled() then
        windower.add_to_chat(123, string.format('[WhereIsNM] NM callback error: %s', tostring(err)))
    end
end

local function register_with_context(zone_id, mob_name, context, mob_id)
    if not context or not context.area or not context.tower or not context.floor then
        return nil
    end

    local area = context.area
    local tower = context.tower
    local floor_number = context.floor

    local spawn_type = (mob_name == '???') and 'question' or 'nm'

    scan_results[#scan_results + 1] = {
        area = area,
        tower = tower,
        floor = floor_number,
        spawn_type = spawn_type,
        mob_name = mob_name,
    }

    queue.queue_spawn_report(area, tower, floor_number, spawn_type, mob_name, 0)

    if spawn_type ~= 'nm' then
        return nil
    end

    local nm_data = {
        name = mob_name,
        area = area,
        tower = tower,
        floor = floor_number,
        mob_id = mob_id,
    }

    dispatch_nm_detected(nm_data)
    return nm_data
end

local function register_from_floor(zone_id, mob_name, floor_name, mob_id)
    if not floor_name then
        return nil
    end

    local area, tower, floor_number = scanner_data.floor_to_api(zone_id, floor_name)
    if not area or not tower or not floor_number then
        if debug_enabled() then
            windower.add_to_chat(123,
                string.format('[WhereIsNM] ERROR: Could not parse floor data for %s', mob_name or 'unknown'))
        end
        return nil
    end

    return register_with_context(zone_id, mob_name, {
        area = area,
        tower = tower,
        floor = floor_number,
    }, mob_id)
end

local function register_entity(zone_id, mob_name, position, mob_id)
    if not position or position[1] == nil or position[2] == nil or position[3] == nil then
        return nil
    end

    local floor_name = scanner_data.find_closest_floor(zone_id, position)

    if not floor_name then
        if debug_enabled() then
            windower.add_to_chat(123,
                string.format('[WhereIsNM] ERROR: Could not determine floor for %s', mob_name or 'unknown'))
        end
        return nil
    end

    return register_from_floor(zone_id, mob_name, floor_name, mob_id)
end

local function scan_without_packets(zone_id)
    if not floor_context or not floor_context.area or not floor_context.tower
        or not floor_context.floor then
        if debug_enabled() then
            windower.add_to_chat(123, '[WhereIsNM] Scan skipped: floor context unavailable')
        end
        return
    end

    mob_scanner.scan({
        zone_id = zone_id,
        is_already_scanned = function(name)
            return scanned_entities[name] == true
        end,
        mark_scanned = function(name)
            scanned_entities[name] = true
        end,
        handle_entity = function(mob_name, position, mob_id)
            register_with_context(zone_id, mob_name, floor_context, mob_id)
        end,
    })
end


function M.trigger_scan()
    local settings = current_settings()
    local zone_info = windower.ffxi.get_info()
    local zone_id = zone_info and zone_info.zone

    if not zone_id or not M.is_limbus_zone(zone_id) then
        return
    end

    if settings and settings.debug then
        windower.add_to_chat(123, '[WhereIsNM] Scanning zone for NMs and ???...')
    end

    scan_active = true
    reset_scan_state(zone_id)

    scan_without_packets(zone_id)
    scan_active = false

    if debug_enabled() then
        windower.add_to_chat(123, '[WhereIsNM] Scan complete')
    end

    dispatch_scan_complete()
end

function M.process_entity_packet(packet_data)
    if not scan_active then return end
    
    local zone_id = windower.ffxi.get_info().zone
    if not M.is_limbus_zone(zone_id) then return end
    
    local mob_index = packet_data:unpack('H', 9)
    local mob_list = windower.ffxi.get_mob_list() or {}
    local mob_name = mob_list[mob_index]
    if not mob_name then return end
    
    if not scanner_data.is_tracked_entity(zone_id, mob_name) then return end
    if scanned_entities[mob_name] then return end
    if bit.band(packet_data:byte(11), 5) ~= 5 then return end
    
    scanned_entities[mob_name] = true
    
    if bit.band(packet_data:byte(33), 6) ~= 0 then return end
    
    local position = {packet_data:unpack('fff', 13)}
    local mob = windower.ffxi.get_mob_by_index(mob_index)
    return register_entity(zone_id, mob_name, position, mob and mob.id or nil)
end

function M.is_limbus_zone(zone_id)
    return scanner_data.is_limbus_zone(zone_id)
end

function M.is_tracked_nm(zone_id, mob_name)
    return scanner_data.is_tracked_nm(zone_id, mob_name)
end

function M.set_scan_complete_callback(callback)
    scan_complete_callback = callback
end

function M.set_nm_detected_callback(callback)
    nm_detected_callback = callback
end

function M.set_floor_context(context)
    if not context or not context.area or not context.tower or not context.floor then
        floor_context = nil
        return
    end

    floor_context = {
        area = context.area,
        tower = context.tower,
        floor = context.floor,
    }
end

return M
