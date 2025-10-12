require('luau')
local bit = require('bit')
local queue = require('util.queue')
local settingsFile = require('util.settings')
require('pack')

local M = {}
local TEMENOS = 37
local APOLLYON = 38

local FLOOR_COORDINATES = {
    [TEMENOS] = {
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
    [APOLLYON] = {
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

local ENTITY_NAMES = {
    [TEMENOS] = {
        ['Agoge'] = {job = 'WAR'}, ["Hesychast's"] = {job = 'MNK'}, ['Piety'] = {job = 'WHM'}, 
        ["Archmage's"] = {job = 'BLM'}, ['Vitiation'] = {job = 'RDM'}, ["Plunderer's"] = {job = 'THF'}, 
        ['Caballarius'] = {job = 'PLD'}, ["Fallen's"] = {job = 'DRK'}, ['Ankusa'] = {job = 'BST'}, 
        ['Bihu'] = {job = 'BRD'}, ['Arcadian'] = {job = 'RNG'}, ['Sakonji'] = {job = 'SAM'},
        ['Mochizuki'] = {job = 'NIN'}, ['Pteroslaver'] = {job = 'DRG'}, ['Glyphic'] = {job = 'SMN'}, 
        ['Luhlaza'] = {job = 'BLU'}, ['Lanun'] = {job = 'COR'}, ['Pitre'] = {job = 'PUP'}, 
        ['Horos'] = {job = 'DNC'}, ['Pedagogy'] = {job = 'SCH'}, ['Bagua'] = {job = 'GEO'}, 
        ['Futhark'] = {job = 'RUN'}, ['???'] = {},
    },
    [APOLLYON] = {
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

local function current_settings()
    return settingsFile.get()
end

local function debug_enabled()
    local settings = current_settings()
    return settings and settings.debug
end

local FLOOR_TO_API = {
    [TEMENOS] = {
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
    [APOLLYON] = {
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

local scanned_entities = {}
local scan_active = false
local scan_results = {}
local scan_complete_callback

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

local function calculate_distance(pos1, pos2)
    local dx = pos2[1] - pos1[1]
    local dy = pos2[2] - pos1[2]
    local dz = pos2[3] - pos1[3]
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function find_closest_floor(zone_id, position)
    if not FLOOR_COORDINATES[zone_id] then return nil end
    
    local closest_distance = math.huge
    local closest_floor = nil
    
    for _, floor_data in ipairs(FLOOR_COORDINATES[zone_id]) do
        local distance = calculate_distance(position, floor_data.pos)
        if distance < closest_distance then
            closest_distance = distance
            closest_floor = floor_data.name
        end
    end
    
    return closest_floor
end

local function floor_to_api_format(zone_id, floor_name)
    if not floor_name or not FLOOR_TO_API[zone_id] then return nil, nil, nil end
    
    local area = (zone_id == TEMENOS) and 'temenos' or 'apollyon'
    local floor_info = FLOOR_TO_API[zone_id][floor_name]
    
    if floor_info then
        return area, floor_info.tower, floor_info.floor
    end
    
    return nil, nil, nil
end

function M.is_limbus_zone(zone_id)
    return zone_id == TEMENOS or zone_id == APOLLYON
end

local function reset_scan_state(zone_id)
    if not ENTITY_NAMES[zone_id] then return end
    
    for entity_name, _ in pairs(ENTITY_NAMES[zone_id]) do
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

function M.trigger_scan()
    local settings = current_settings()
    local zone_id = windower.ffxi.get_info().zone
    
    if not M.is_limbus_zone(zone_id) then
        return
    end  

    if settings and settings.debug then 
        windower.add_to_chat(123, '[WhereIsNM] Scanning zone for NMs and ???...')
    end

    scan_active = true
    reset_scan_state(zone_id)
    
    local mob_list = windower.ffxi.get_mob_list()
    local packet_count = 0
    
    for mob_index, mob_name in pairs(mob_list) do
        if ENTITY_NAMES[zone_id][mob_name] then
            windower.packets.inject_outgoing(0x016, string.pack('IHH', 0x0216, mob_index, 0))
            packet_count = packet_count + 1
        end
    end
       
    coroutine.schedule(function()
        scan_active = false
        if debug_enabled() then 
            windower.add_to_chat(123, '[WhereIsNM] Scan complete')
        end

        dispatch_scan_complete()
    end, 2)
end

function M.process_entity_packet(packet_data)
    if not scan_active then return end
    
    local zone_id = windower.ffxi.get_info().zone
    if not M.is_limbus_zone(zone_id) then return end
    
    local mob_index = packet_data:unpack('H', 9)
        local mob_name = windower.ffxi.get_mob_list()[mob_index]
    if not mob_name then return end
    
    if not ENTITY_NAMES[zone_id][mob_name] then return end
    if scanned_entities[mob_name] then return end
        if bit.band(packet_data:byte(11), 5) ~= 5 then return end
    
    scanned_entities[mob_name] = true
    
    if bit.band(packet_data:byte(33), 6) ~= 0 then return end
    
    local position = {packet_data:unpack('fff', 13)}
    local floor_name = find_closest_floor(zone_id, position)
    
    if not floor_name then
        if debug_enabled() then 
            windower.add_to_chat(123, string.format('[WhereIsNM] ERROR: Could not determine floor for %s', mob_name))
        end

        return
    end
    
    local area, tower, floor_number = floor_to_api_format(zone_id, floor_name)
    
    if not area or not tower or not floor_number then
        if debug_enabled() then 
            windower.add_to_chat(123, string.format('[WhereIsNM] ERROR: Could not parse floor data for %s', mob_name))
        end

        return
    end
    
    local spawn_type = (mob_name == '???') and 'question' or 'nm'
    local display_name = mob_name
    
    if spawn_type == 'nm' and ENTITY_NAMES[zone_id][mob_name].job then
        display_name = string.format('%s (%s)', mob_name, ENTITY_NAMES[zone_id][mob_name].job)
    end

    scan_results[#scan_results + 1] = {
        area = area,
        tower = tower,
        floor = floor_number,
        spawn_type = spawn_type,
        mob_name = mob_name,
    }
    
    queue.queue_spawn_report(area, tower, floor_number, spawn_type, mob_name, 0)
    
    if spawn_type == 'nm' then
        local mob = windower.ffxi.get_mob_by_index(mob_index)
        
        return {
            name = mob_name,
            area = area,
            tower = tower,
            floor = floor_number,
            mob_id = mob and mob.id or nil
        }
    end
end

function M.is_tracked_nm(zone_id, mob_name)
    if not ENTITY_NAMES[zone_id] then return false end
    return ENTITY_NAMES[zone_id][mob_name] ~= nil and mob_name ~= '???'
end

function M.set_scan_complete_callback(callback)
    scan_complete_callback = callback
end

return M
