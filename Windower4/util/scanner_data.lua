require('luau')

local Data = {}

Data.TEMENOS = 37
Data.APOLLYON = 38

Data.FLOOR_COORDINATES = {
    [Data.TEMENOS] = {
        {name = 'Entrance', pos = {580.00, 86.00, 0.00}},
        {name = 'Northern Tower - 1st Floor', pos = {340.0, 71.62, 376.0}},
        {name = 'Northern Tower - 2nd Floor', pos = {220.0, -82.38, 376.0}},
        {name = 'Northern Tower - 3rd Floor', pos = {20.0, 71.62, 376.0}},
        {name = 'Northern Tower - 4th Floor', pos = {-100.0, -82.38, 376.0}},
        {name = 'Northern Tower - 5th Floor', pos = {-300.0, 77.62, 376.0}},
        {name = 'Northern Tower - 6th Floor', pos = {-420.0, -82.38, 376.0}},
        {name = 'Northern Tower - 7th Floor', pos = {-620.0, 77.62, 376.0}},
        {name = 'Western Tower - 1st Floor', pos = {340.0, -2.38, 96.0}},
        {name = 'Western Tower - 2nd Floor', pos = {220.0, -162.38, 96.0}},
        {name = 'Western Tower - 3rd Floor', pos = {20.0, -2.38, 96.0}},
        {name = 'Western Tower - 4th Floor', pos = {-100.0, -162.38, 96.0}},
        {name = 'Western Tower - 5th Floor', pos = {-300.0, -2.38, 96.0}},
        {name = 'Western Tower - 6th Floor', pos = {-420.0, -162.38, 96.0}},
        {name = 'Western Tower - 7th Floor', pos = {-620.0, -2.38, 96.0}},
        {name = 'Eastern Tower - 1st Floor', pos = {340.0, 71.62, -184.0}},
        {name = 'Eastern Tower - 2nd Floor', pos = {220.0, -82.38, -184.0}},
        {name = 'Eastern Tower - 3rd Floor', pos = {20.0, 71.62, -184.0}},
        {name = 'Eastern Tower - 4th Floor', pos = {-100.0, -82.38, -184.0}},
        {name = 'Eastern Tower - 5th Floor', pos = {-300.0, 77.62, -184.0}},
        {name = 'Eastern Tower - 6th Floor', pos = {-420.0, -82.38, -184.0}},
        {name = 'Eastern Tower - 7th Floor', pos = {-620.0, 77.62, -184.0}},
        {name = 'Central Tower - 1st Floor', pos = {540.0, -2.38, -544.0}},
        {name = 'Central Tower - 2nd Floor', pos = {300.0, -162.38, -504.0}},
        {name = 'Central Tower - 3rd Floor', pos = {-20.0, -2.38, -544.0}},
        {name = 'Central Tower - 4th Floor', pos = {-264.0, -162.38, -500.0}},
    },
    [Data.APOLLYON] = {
        {name = 'Entrance 1', pos = {608.00, -600.00, -0.00}},
        {name = 'Entrance 2', pos = {-608.00, -600.00, -0.00}},
        {name = 'NW #1', pos = {-400.0, -0.5, 80.0}},
        {name = 'NW #2', pos = {-560.0, -0.5, 360.0}},
        {name = 'NW #3', pos = {-280.0, -0.5, 360.0}},
        {name = 'NW #4', pos = {-520.0, -0.5, 640.0}},
        {name = 'NW #5', pos = {-240.0, -0.5, 520.0}},
        {name = 'SW #1', pos = {-400.0, -0.5, -520.0}},
        {name = 'SW #2', pos = {-520.0, -0.5, -320.0}},
        {name = 'SW #3', pos = {-280.0, -0.5, -280.0}},
        {name = 'SW #4', pos = {-120.0, -0.5, -440.0}},
        {name = 'NE #1', pos = {400.0, -0.5, 80.0}},
        {name = 'NE #2', pos = {560.0, -0.5, 360.0}},
        {name = 'NE #3', pos = {280.0, -0.5, 360.0}},
        {name = 'NE #4', pos = {520.0, -0.5, 640.0}},
        {name = 'NE #5', pos = {240.0, -0.5, 520.0}},
        {name = 'SE #1', pos = {400.0, -0.5, -520.0}},
        {name = 'SE #2', pos = {520.0, -0.5, -320.0}},
        {name = 'SE #3', pos = {280.0, -0.5, -280.0}},
        {name = 'SE #4', pos = {120.0, -0.5, -440.0}},
    },
}

Data.ENTITY_NAMES = {
    [Data.TEMENOS] = {
        ['Agoge'] = {job = 'WAR'}, ["Hesychast's"] = {job = 'MNK'}, ['Piety'] = {job = 'WHM'},
        ["Archmage's"] = {job = 'BLM'}, ['Vitiation'] = {job = 'RDM'}, ["Plunderer's"] = {job = 'THF'},
        ['Caballarius'] = {job = 'PLD'}, ["Fallen's"] = {job = 'DRK'}, ['Ankusa'] = {job = 'BST'},
        ['Bihu'] = {job = 'BRD'}, ['Arcadian'] = {job = 'RNG'}, ['Sakonji'] = {job = 'SAM'},
        ['Mochizuki'] = {job = 'NIN'}, ['Pteroslaver'] = {job = 'DRG'}, ['Glyphic'] = {job = 'SMN'},
        ['Luhlaza'] = {job = 'BLU'}, ['Lanun'] = {job = 'COR'}, ['Pitre'] = {job = 'PUP'},
        ['Horos'] = {job = 'DNC'}, ['Pedagogy'] = {job = 'SCH'}, ['Bagua'] = {job = 'GEO'},
        ['Futhark'] = {job = 'RUN'}, ['???'] = {},
    },
    [Data.APOLLYON] = {
        ["Pummeler's"] = {job = 'WAR'}, ["Anchorite's"] = {job = 'MNK'}, ['Theophany'] = {job = 'WHM'},
        ["Spaekona's"] = {job = 'BLM'}, ['Atrophy'] = {job = 'RDM'}, ["Pillager's"] = {job = 'THF'},
        ['Reverence'] = {job = 'PLD'}, ['Ignominy'] = {job = 'DRK'}, ['Totemic'] = {job = 'BST'},
        ['Brioso'] = {job = 'BRD'}, ['Orion'] = {job = 'RNG'}, ['Wakido'] = {job = 'SAM'},
        ['Hachiya'] = {job = 'NIN'}, ['Vishap'] = {job = 'DRG'}, ["Convoker's"] = {job = 'SMN'},
        ["Assimilator's"] = {job = 'BLU'}, ["Laksamana's"] = {job = 'COR'}, ['Foire'] = {job = 'PUP'},
        ['Maxixi'] = {job = 'DNC'}, ["Academic's"] = {job = 'SCH'}, ['Geomancy'] = {job = 'GEO'},
        ['Runeist'] = {job = 'RUN'}, ['???'] = {},
    },
}

Data.FLOOR_TO_API = {
    [Data.TEMENOS] = {
        ['Entrance'] = {tower = 'entrance', floor = 0},
        ['Northern Tower - 1st Floor'] = {tower = 'northern', floor = 1},
        ['Northern Tower - 2nd Floor'] = {tower = 'northern', floor = 2},
        ['Northern Tower - 3rd Floor'] = {tower = 'northern', floor = 3},
        ['Northern Tower - 4th Floor'] = {tower = 'northern', floor = 4},
        ['Northern Tower - 5th Floor'] = {tower = 'northern', floor = 5},
        ['Northern Tower - 6th Floor'] = {tower = 'northern', floor = 6},
        ['Northern Tower - 7th Floor'] = {tower = 'northern', floor = 7},
        ['Western Tower - 1st Floor'] = {tower = 'western', floor = 1},
        ['Western Tower - 2nd Floor'] = {tower = 'western', floor = 2},
        ['Western Tower - 3rd Floor'] = {tower = 'western', floor = 3},
        ['Western Tower - 4th Floor'] = {tower = 'western', floor = 4},
        ['Western Tower - 5th Floor'] = {tower = 'western', floor = 5},
        ['Western Tower - 6th Floor'] = {tower = 'western', floor = 6},
        ['Western Tower - 7th Floor'] = {tower = 'western', floor = 7},
        ['Eastern Tower - 1st Floor'] = {tower = 'eastern', floor = 1},
        ['Eastern Tower - 2nd Floor'] = {tower = 'eastern', floor = 2},
        ['Eastern Tower - 3rd Floor'] = {tower = 'eastern', floor = 3},
        ['Eastern Tower - 4th Floor'] = {tower = 'eastern', floor = 4},
        ['Eastern Tower - 5th Floor'] = {tower = 'eastern', floor = 5},
        ['Eastern Tower - 6th Floor'] = {tower = 'eastern', floor = 6},
        ['Eastern Tower - 7th Floor'] = {tower = 'eastern', floor = 7},
        ['Central Tower - 1st Floor'] = {tower = 'central', floor = 1},
        ['Central Tower - 2nd Floor'] = {tower = 'central', floor = 2},
        ['Central Tower - 3rd Floor'] = {tower = 'central', floor = 3},
        ['Central Tower - 4th Floor'] = {tower = 'central', floor = 4},
    },
    [Data.APOLLYON] = {
        ['Entrance 1'] = {tower = 'entrance', floor = 0},
        ['Entrance 2'] = {tower = 'entrance', floor = 0},
        ['NW #1'] = {tower = 'nw', floor = 1},
        ['NW #2'] = {tower = 'nw', floor = 2},
        ['NW #3'] = {tower = 'nw', floor = 3},
        ['NW #4'] = {tower = 'nw', floor = 4},
        ['NW #5'] = {tower = 'nw', floor = 5},
        ['SW #1'] = {tower = 'sw', floor = 1},
        ['SW #2'] = {tower = 'sw', floor = 2},
        ['SW #3'] = {tower = 'sw', floor = 3},
        ['SW #4'] = {tower = 'sw', floor = 4},
        ['NE #1'] = {tower = 'ne', floor = 1},
        ['NE #2'] = {tower = 'ne', floor = 2},
        ['NE #3'] = {tower = 'ne', floor = 3},
        ['NE #4'] = {tower = 'ne', floor = 4},
        ['NE #5'] = {tower = 'ne', floor = 5},
        ['SE #1'] = {tower = 'se', floor = 1},
        ['SE #2'] = {tower = 'se', floor = 2},
        ['SE #3'] = {tower = 'se', floor = 3},
        ['SE #4'] = {tower = 'se', floor = 4},
    },
}

local function calculate_distance(pos1, pos2)
    local dx = pos2[1] - pos1[1]
    local dy = pos2[2] - pos1[2]
    local dz = pos2[3] - pos1[3]
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function Data.find_closest_floor(zone_id, position)
    local floors = Data.FLOOR_COORDINATES[zone_id]
    if not floors then
        return nil
    end

    local closest_distance = math.huge
    local closest_floor = nil

    for _, floor_data in ipairs(floors) do
        local distance = calculate_distance(position, floor_data.pos)
        if distance < closest_distance then
            closest_distance = distance
            closest_floor = floor_data.name
        end
    end

    return closest_floor
end

function Data.floor_to_api(zone_id, floor_name)
    if not floor_name then
        return nil, nil, nil
    end

    local mapping = Data.FLOOR_TO_API[zone_id]
    if not mapping then
        return nil, nil, nil
    end

    local floor_info = mapping[floor_name]
    if not floor_info then
        return nil, nil, nil
    end

    local area = (zone_id == Data.TEMENOS) and 'temenos' or 'apollyon'
    return area, floor_info.tower, floor_info.floor
end

function Data.is_limbus_zone(zone_id)
    return zone_id == Data.TEMENOS or zone_id == Data.APOLLYON
end

function Data.is_tracked_nm(zone_id, mob_name)
    local zone_list = Data.ENTITY_NAMES[zone_id]
    if not zone_list then
        return false
    end

    return zone_list[mob_name] ~= nil and mob_name ~= '???'
end

function Data.is_tracked_entity(zone_id, mob_name)
    local zone_list = Data.ENTITY_NAMES[zone_id]
    return zone_list ~= nil and zone_list[mob_name] ~= nil
end

function Data.get_entity(zone_id, mob_name)
    local zone_list = Data.ENTITY_NAMES[zone_id]
    if not zone_list then
        return nil
    end
    return zone_list[mob_name]
end

return Data
