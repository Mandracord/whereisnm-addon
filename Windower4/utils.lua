require('luau')

local M = {}

M.limbus_nms = {
    [37] = S{ -- Temenos
        'Agoge', 'Hesychast\'s', 'Piety', 'Archmage\'s', 'Vitiation', 'Plunderer\'s', 
        'Caballarius', 'Fallen\'s', 'Ankusa', 'Bihu', 'Arcadian', 'Sakonjin', 
        'Mochizuki', 'Pteroslav', 'Glyphic', 'Luhlaza', 'Lanun', 'Pitre', 
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

return M