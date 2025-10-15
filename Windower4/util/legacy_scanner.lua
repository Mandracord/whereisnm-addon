require('luau')

local scanner_data = require('util.scanner_data')

local LegacyScanner = {}

local function safe_distance(distance_field)
    if not distance_field then
        return nil
    end

    if type(distance_field) == 'number' then
        if distance_field < 0 then
            return nil
        end
        return math.sqrt(distance_field)
    end

    if type(distance_field) == 'table' and type(distance_field.sqrt) == 'function' then
        local ok, value = pcall(function()
            return distance_field:sqrt()
        end)
        if ok then
            return value
        end
    end

    return nil
end

local function is_within_detection_range(mob)
    local distance = safe_distance(mob.distance)
    if not distance then
        return true
    end
    return distance <= 50
end

local function is_valid_candidate(zone_id, mob)
    if not mob or not mob.name then
        return false
    end

    if not scanner_data.is_tracked_entity(zone_id, mob.name) then
        return false
    end

    if mob.valid_target == false then
        return false
    end

    if mob.x == nil or mob.y == nil or mob.z == nil then
        return false
    end

    return is_within_detection_range(mob)
end

---Scan the visible mob array using legacy heuristics.
---@param opts table
function LegacyScanner.scan(opts)
    opts = opts or {}

    local zone_id = opts.zone_id
    if not zone_id or not scanner_data.is_limbus_zone(zone_id) then
        return
    end

    local is_already_scanned = opts.is_already_scanned or function()
        return false
    end

    local mark_scanned = opts.mark_scanned or function() end
    local handle_entity = opts.handle_entity or function() end

    local mob_array = windower.ffxi.get_mob_array()
    if type(mob_array) ~= 'table' then
        return
    end

    for _, mob in pairs(mob_array) do
        if is_valid_candidate(zone_id, mob) then
            if not is_already_scanned(mob.name) then
                mark_scanned(mob.name)
                handle_entity(mob.name, {mob.x, mob.y, mob.z}, mob.id)
            end
        end
    end
end

return LegacyScanner
