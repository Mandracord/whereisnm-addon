require('luau')
api = require('util/api')
queue = require('util/queue')
formatter = require('util/format')

local M = {}
local tracked_nm = nil
local queued_tod_keys = {}

M.limbus_nms = {
    [37] = S{ -- Temenos
        'Agoge', 'Hesychast\'s', 'Piety', 'Archmage\'s', 'Vitiation', 'Plunderer\'s', 
        'Caballarius', 'Fallen\'s', 'Ankusa', 'Bihu', 'Arcadian', 'Sakonji', 
        'Mochizuki', 'Pteroslaver', 'Glyphic', 'Luhlaza', 'Lanun', 'Pitre', 
        'Horos', 'Pedagogy', 'Bagua', 'Futhark'
    },
    [38] = S{ -- Apollyon  
        'Pummeler\'s', 'Anchorite\'s', 'Theophany', 'Spaekona\'s', 'Atrophy', 'Pillager\'s',
        'Reverence', 'Ignominy', 'Totemic', 'Brioso', 'Orion', 'Wakido', 'Hachiya', 
        'Vishap', 'Convoker\'s', 'Assimilator\'s', 'Laksamana\'s', 'Foire', 'Maxixi', 
        'Academic\'s', 'Geomancy', 'Runeist'
    }
}

M.floor_coordinates = {
    [37] = { -- Temenos
        {name="Temenos Northern F1", x=380, y=376, z=72},
        {name="Temenos Northern F2", x=180, y=376, z=-82},
        {name="Temenos Northern F3", x=60, y=376, z=72},
        {name="Temenos Northern F4", x=-140, y=376, z=-82},
        {name="Temenos Northern F5", x=-260, y=376, z=78},
        {name="Temenos Northern F6", x=-460, y=376, z=-82},
        {name="Temenos Northern F7", x=-580, y=376, z=78},
        {name="Temenos Western F1", x=380, y=96, z=-2},
        {name="Temenos Western F2", x=180, y=96, z=-162},
        {name="Temenos Western F3", x=60, y=96, z=-2},
        {name="Temenos Western F4", x=-140, y=96, z=-162},
        {name="Temenos Western F5", x=-260, y=96, z=-2},
        {name="Temenos Western F6", x=-460, y=96, z=-162},
        {name="Temenos Western F7", x=-580, y=96, z=-2},
        {name="Temenos Eastern F1", x=380, y=-184, z=72},
        {name="Temenos Eastern F2", x=180, y=-184, z=-82},
        {name="Temenos Eastern F3", x=60, y=-184, z=72},
        {name="Temenos Eastern F4", x=-140, y=-184, z=-82},
        {name="Temenos Eastern F5", x=-260, y=-184, z=78},
        {name="Temenos Eastern F6", x=-460, y=-184, z=-82},
        {name="Temenos Eastern F7", x=-580, y=-184, z=78},
        {name="Temenos Central F1", x=580, y=-544, z=-2},
        {name="Temenos Central F2", x=260, y=-504, z=-162},
        {name="Temenos Central F3", x=20, y=-544, z=-2},
        {name="Temenos Central F4", x=-296, y=-500, z=-162}
    },
    [38] = { -- Apollyon
        {name="Apollyon NW F1", x=-440, y=-88, z=0},
        {name="Apollyon NW F2", x=-534, y=171, z=0},
        {name="Apollyon NW F3", x=-294, y=171, z=0},
        {name="Apollyon NW F4", x=-628, y=497, z=0},
        {name="Apollyon NW F5", x=-388, y=498, z=0},
        {name="Apollyon SW F1", x=-468, y=-625, z=0},
        {name="Apollyon SW F2", x=-576, y=-428, z=0},
        {name="Apollyon SW F3", x=-428, y=-385, z=0},
        {name="Apollyon SW F4", x=-176, y=-628, z=0},
        {name="Apollyon NE F1", x=440, y=-88, z=0},
        {name="Apollyon NE F2", x=534, y=171, z=0},
        {name="Apollyon NE F3", x=294, y=171, z=0},
        {name="Apollyon NE F4", x=628, y=497, z=0},
        {name="Apollyon NE F5", x=388, y=498, z=0},
        {name="Apollyon SE F1", x=468, y=-625, z=0},
        {name="Apollyon SE F2", x=576, y=-428, z=0},
        {name="Apollyon SE F3", x=428, y=-385, z=0},
        {name="Apollyon SE F4", x=176, y=-628, z=0}
    }
}

function M.identify_floor(player_x, player_y, player_z, zone_id)
    local floors = M.floor_coordinates[zone_id]
    if not floors then return nil end
    
    for _, floor in ipairs(floors) do
        if math.abs(player_x - floor.x) < 10 and 
           math.abs(player_y - floor.y) < 10 and 
           math.abs(player_z - floor.z) < 10 then
            return floor.name
        end
    end
    return nil
end

function M.parse_floor_to_api_format(floor_name, zone_id)
    if not floor_name then return nil, nil, nil end
    
    if zone_id == 37 then
        local tower, floor_num = floor_name:match("Temenos (%w+) F(%d+)")
        if tower and floor_num then
            return 'temenos', tower:lower(), tonumber(floor_num)
        end
    elseif zone_id == 38 then
        local tower, floor_num = floor_name:match("Apollyon (%w+) F(%d+)")
        if tower and floor_num then
            return 'apollyon', tower:lower(), tonumber(floor_num)
        end
    end
    
    return nil, nil, nil
end

function M.clear_tod_tracking()
    queued_tod_keys = {}
end

function M.check_and_track_tod(current_floor)
    local player = windower.ffxi.get_player()
    local zone_info = windower.ffxi.get_info()
    
    if not player or not zone_info then return end
    if zone_info.zone ~= 37 and zone_info.zone ~= 38 then 
        if tracked_nm then
            tracked_nm = nil
        end
        return 
    end
    
    if tracked_nm and tracked_nm.floor_name and tracked_nm.floor_name ~= current_floor then
        tracked_nm = nil
    end
    
    local target = windower.ffxi.get_mob_by_target('t')
    
    if target and M.limbus_nms[zone_info.zone]:contains(target.name) and not tracked_nm then
        if current_floor then
            local area, tower, floor = M.parse_floor_to_api_format(current_floor, zone_info.zone)
            if area and tower and floor then
                tracked_nm = {
                    id = target.id,
                    name = target.name,
                    area = area,
                    tower = tower,
                    floor = floor,
                    floor_name = current_floor,
                    tod_reported = false,
                    last_hpp = target.hpp 
                }
            end
        end
    end
    
    if tracked_nm and not tracked_nm.tod_reported then
        local mob = windower.ffxi.get_mob_by_id(tracked_nm.id)
        
        if mob then
            tracked_nm.last_hpp = mob.hpp
        end

        local should_report = false
        if not mob and tracked_nm.last_hpp <= 1 then
            should_report = true
        elseif mob and mob.hpp <= 1 then
            should_report = true
        end

        if should_report then
            local tod_key = string.format("%s_%s_%d_%s",
                tracked_nm.area,
                tracked_nm.tower,
                tracked_nm.floor,
                tracked_nm.name
            )
            
            if not queued_tod_keys[tod_key] then
                tracked_nm.tod_reported = true
                
                queue.queue_tod_report(
                    tracked_nm.area,
                    tracked_nm.tower,
                    tracked_nm.floor,
                    tracked_nm.name,
                    nil
                )
                
                windower.add_to_chat(123, string.format('[WhereIsNM] TOD queued for %s', tracked_nm.name))
                
                queued_tod_keys[tod_key] = true
            end
            
            tracked_nm = nil
        end
    end
end

function M.format_box_display(reports)
    if not reports or reports == "Unable to fetch latest data" then
        return "No recent data"
    end
    
    local lines = {}
    for line in reports:gmatch("[^\r\n]+") do
        if (line:match("^[%s]*[A-Z]") or line:match("^[%s]*%?%?%?")) and not line:match("^Reported NM") and not line:match("^Reported %?%?%?") then
            line = line:gsub("^%s+", ""):gsub("%s+$", "")
            if #line > 0 then
                table.insert(lines, line)
            end
        end
    end
    
    if #lines == 0 then
        return "No recent data"
    end
    
    return table.concat(lines, "\n")
end

return M