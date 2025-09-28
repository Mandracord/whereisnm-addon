require('luau')
require('strings')

local M = {}

-- Format location names with proper capitalization and auto-translate support
function M.format_location_name(name) 
    if not name or name == "" then 
        return name 
    end
    
    -- Convert auto-translate if present
    local clean_name = windower.convert_auto_trans(name)
    
    return clean_name:sub(1,1):upper() .. clean_name:sub(2) 
end

-- Format time ago display
function M.format_time_ago(minutes)
    if not minutes or minutes < 0 then
        return "unknown"
    end
    
    if minutes < 60 then
        return string.format("%dm", math.floor(minutes))
    else
        local hours = math.floor(minutes / 60)
        local mins = math.floor(minutes % 60)
        return string.format("%dh %dm", hours, mins)
    end
end

-- Format spawn type for display
function M.format_spawn_type(spawn_type)
    if spawn_type == "nm" then
        return "NM"
    elseif spawn_type == "question" then
        return "???"
    else
        return spawn_type or "Unknown"
    end
end

-- Format enemy text with parentheses if present
function M.format_enemy_text(mob_name)
    return mob_name and (" (" .. mob_name .. ")") or ""
end

-- Format floor display
function M.format_floor_display(area, tower, floor)
    local formatted_area = M.format_location_name(area)
    local formatted_tower = M.format_location_name(tower)
    return string.format("%s %s F%d", formatted_area, formatted_tower, floor)
end

-- Format complete spawn report
function M.format_spawn_report(spawn_type, area, tower, floor, mob_name, distance)
    local spawn_text = M.format_spawn_type(spawn_type)
    local location = M.format_floor_display(area, tower, floor)
    local enemy_text = M.format_enemy_text(mob_name)
    local distance_text = distance and string.format(" (%.2fy)", distance) or ""
    
    return string.format('%s reported: %s%s%s', spawn_text, location, enemy_text, distance_text)
end

-- Format TOD report
function M.format_tod_report(area, tower, floor, enemy_input, job_or_name)
    local formatted_area = M.format_location_name(area)
    
    if tower and floor then
        local formatted_tower = M.format_location_name(tower)
        local enemy_text = M.format_enemy_text(enemy_input)
        return string.format('[WhereIsNM] TOD reported: %s, %s F%d%s', formatted_area, formatted_tower, floor, enemy_text)
    elseif job_or_name then
        return string.format('[WhereIsNM] TOD reported: %s - %s', formatted_area, job_or_name)
    else
        return string.format('[WhereIsNM] TOD reported: %s', formatted_area)
    end
end

return M