local packets = require('packets')

local FloorDetector = {}

local temenos_floor_positions = {
    {key = 'Temenos:Entrance', display = 'Temenos Entrance', x = 580.0, y = 86.0, z = 0.0, radius_sq = 400},
    {key = 'Temenos:N1', display = 'Temenos Northern Tower 1', x = 380.00003051758, y = 376.00003051758, z = 71.620002746582},
    {key = 'Temenos:N2', display = 'Temenos Northern Tower 2', x = 180.00001525879, y = 376.00003051758, z = -82.380004882812},
    {key = 'Temenos:N3', display = 'Temenos Northern Tower 3', x = 60.000003814697, y = 376.00003051758, z = 71.620002746582},
    {key = 'Temenos:N4', display = 'Temenos Northern Tower 4', x = -140.0, y = 376.00003051758, z = -82.380004882812},
    {key = 'Temenos:N5', display = 'Temenos Northern Tower 5', x = -260.0, y = 376.00003051758, z = 77.620002746582},
    {key = 'Temenos:N6', display = 'Temenos Northern Tower 6', x = -460.00003051758, y = 376.00003051758, z = -82.380004882812},
    {key = 'Temenos:N7', display = 'Temenos Northern Tower 7', x = -580.0, y = 376.00003051758, z = 77.620002746582},
    {key = 'Temenos:W1', display = 'Temenos Western Tower 1', x = 380.00003051758, y = 96.000007629395, z = -2.3800001144409},
    {key = 'Temenos:W2', display = 'Temenos Western Tower 2', x = 180.00001525879, y = 96.000007629395, z = -162.38000488281},
    {key = 'Temenos:W3', display = 'Temenos Western Tower 3', x = 60.000003814697, y = 96.000007629395, z = -2.3800001144409},
    {key = 'Temenos:W4', display = 'Temenos Western Tower 4', x = -140.0, y = 96.000007629395, z = -162.38000488281},
    {key = 'Temenos:W5', display = 'Temenos Western Tower 5', x = -260.0, y = 96.000007629395, z = -2.3800001144409},
    {key = 'Temenos:W6', display = 'Temenos Western Tower 6', x = -460.00003051758, y = 96.000007629395, z = -162.38000488281},
    {key = 'Temenos:W7', display = 'Temenos Western Tower 7', x = -580.0, y = 96.000007629395, z = -2.3800001144409},
    {key = 'Temenos:E1', display = 'Temenos Eastern Tower 1', x = 380.00003051758, y = -184.00001525879, z = 71.620002746582},
    {key = 'Temenos:E2', display = 'Temenos Eastern Tower 2', x = 180.00001525879, y = -184.00001525879, z = -82.380004882812},
    {key = 'Temenos:E3', display = 'Temenos Eastern Tower 3', x = 60.000003814697, y = -184.00001525879, z = 71.620002746582},
    {key = 'Temenos:E4', display = 'Temenos Eastern Tower 4', x = -140.0, y = -184.00001525879, z = -82.380004882812},
    {key = 'Temenos:E5', display = 'Temenos Eastern Tower 5', x = -260.0, y = -184.00001525879, z = 77.620002746582},
    {key = 'Temenos:E6', display = 'Temenos Eastern Tower 6', x = -460.00003051758, y = -184.00001525879, z = -82.380004882812},
    {key = 'Temenos:E7', display = 'Temenos Eastern Tower 7', x = -580.0, y = -184.00001525879, z = 77.620002746582},
    {key = 'Temenos:C1', display = 'Temenos Central Tower 1', x = 580.0, y = -544.0, z = -2.3800001144409},
    {key = 'Temenos:C2', display = 'Temenos Central Tower 2', x = 260.0, y = -504.00003051758, z = -162.38000488281},
    {key = 'Temenos:C3', display = 'Temenos Central Tower 3', x = 20.0, y = -544.0, z = -2.3800001144409},
    {key = 'Temenos:C4', display = 'Temenos Central Tower 4', x = -296.0, y = -500.00003051758, z = -162.38000488281},
}

local apollyon_floor_positions = {
    {key = 'Apollyon:Entrance1', display = 'Apollyon Entrance 1', x = -608.0, y = -600.0, z = 0.0, radius_sq = 2500},
    {key = 'Apollyon:Entrance2', display = 'Apollyon Entrance 2', x = 608.0, y = -600.0, z = 0.0, radius_sq = 2500},
    {key = 'Apollyon:NW1', display = 'Apollyon Northwest 1', x = -440.00003051758, y = -88.000007629395, z = 0.0},
    {key = 'Apollyon:NW2', display = 'Apollyon Northwest 2', x = -534.0, y = 171.00001525879, z = 0.0},
    {key = 'Apollyon:NW3', display = 'Apollyon Northwest 3', x = -294.0, y = 171.00001525879, z = 0.0},
    {key = 'Apollyon:NW4', display = 'Apollyon Northwest 4', x = -628.0, y = 497.00003051758, z = 0.0},
    {key = 'Apollyon:NW5', display = 'Apollyon Northwest 5', x = -388.0, y = 498.00003051758, z = 0.0},
    {key = 'Apollyon:SW1', display = 'Apollyon Southwest 1', x = -468.00003051758, y = -625.0, z = 0.0},
    {key = 'Apollyon:SW2', display = 'Apollyon Southwest 2', x = -576.0, y = -428.00003051758, z = 0.0},
    {key = 'Apollyon:SW3', display = 'Apollyon Southwest 3', x = -428.00003051758, y = -385.00003051758, z = 0.0},
    {key = 'Apollyon:SW4', display = 'Apollyon Southwest 4', x = -176.00001525879, y = -628.0, z = 0.0},
    {key = 'Apollyon:NE1', display = 'Apollyon Northeast 1', x = 440.00003051758, y = -88.000007629395, z = 0.0},
    {key = 'Apollyon:NE2', display = 'Apollyon Northeast 2', x = 534.0, y = 171.00001525879, z = 0.0},
    {key = 'Apollyon:NE3', display = 'Apollyon Northeast 3', x = 294.0, y = 171.00001525879, z = 0.0},
    {key = 'Apollyon:NE4', display = 'Apollyon Northeast 4', x = 628.0, y = 497.00003051758, z = 0.0},
    {key = 'Apollyon:NE5', display = 'Apollyon Northeast 5', x = 388.00003051758, y = 498.00003051758, z = 0.0},
    {key = 'Apollyon:SE1', display = 'Apollyon Southeast 1', x = 468.00003051758, y = -625.0, z = 0.0},
    {key = 'Apollyon:SE2', display = 'Apollyon Southeast 2', x = 576.0, y = -428.00003051758, z = 0.0},
    {key = 'Apollyon:SE3', display = 'Apollyon Southeast 3', x = 428.00003051758, y = -385.00003051758, z = 0.0},
    {key = 'Apollyon:SE4', display = 'Apollyon Southeast 4', x = 176.00001525879, y = -628.0, z = 0.0},
}

local floor_zones = {
    [37] = {
        positions = temenos_floor_positions,
        radius_sq = 900,
    },
    [38] = {
        positions = apollyon_floor_positions,
        radius_sq = 1600,
    },
}

local floor_menu_lookup = {
    [1000] = {[1] = {key = 'Temenos:Entrance', display = 'Temenos Entrance'}},
    [1001] = {[11] = {key = 'Temenos:N1', display = 'Temenos Northern Tower 1'}},
    [1002] = {[12] = {key = 'Temenos:N2', display = 'Temenos Northern Tower 2'}},
    [1003] = {[13] = {key = 'Temenos:N3', display = 'Temenos Northern Tower 3'}},
    [1004] = {[14] = {key = 'Temenos:N4', display = 'Temenos Northern Tower 4'}},
    [1005] = {[15] = {key = 'Temenos:N5', display = 'Temenos Northern Tower 5'}},
    [1006] = {[16] = {key = 'Temenos:N6', display = 'Temenos Northern Tower 6'}},
    [1007] = {[17] = {key = 'Temenos:N7', display = 'Temenos Northern Tower 7'}},
    [1008] = {[21] = {key = 'Temenos:W1', display = 'Temenos Western Tower 1'}},
    [1009] = {[22] = {key = 'Temenos:W2', display = 'Temenos Western Tower 2'}},
    [1010] = {[23] = {key = 'Temenos:W3', display = 'Temenos Western Tower 3'}},
    [1011] = {[24] = {key = 'Temenos:W4', display = 'Temenos Western Tower 4'}},
    [1012] = {[25] = {key = 'Temenos:W5', display = 'Temenos Western Tower 5'}},
    [1013] = {[26] = {key = 'Temenos:W6', display = 'Temenos Western Tower 6'}},
    [1014] = {[27] = {key = 'Temenos:W7', display = 'Temenos Western Tower 7'}},
    [1015] = {[31] = {key = 'Temenos:E1', display = 'Temenos Eastern Tower 1'}},
    [1016] = {[32] = {key = 'Temenos:E2', display = 'Temenos Eastern Tower 2'}},
    [1017] = {[33] = {key = 'Temenos:E3', display = 'Temenos Eastern Tower 3'}},
    [1018] = {[34] = {key = 'Temenos:E4', display = 'Temenos Eastern Tower 4'}},
    [1019] = {[35] = {key = 'Temenos:E5', display = 'Temenos Eastern Tower 5'}},
    [1020] = {[36] = {key = 'Temenos:E6', display = 'Temenos Eastern Tower 6'}},
    [1021] = {[37] = {key = 'Temenos:E7', display = 'Temenos Eastern Tower 7'}},
    [1022] = {[41] = {key = 'Temenos:C1', display = 'Temenos Central Tower 1'}},
    [1023] = {[42] = {key = 'Temenos:C2', display = 'Temenos Central Tower 2'}},
    [1024] = {[43] = {key = 'Temenos:C3', display = 'Temenos Central Tower 3'}},
    [1025] = {[44] = {key = 'Temenos:C4', display = 'Temenos Central Tower 4'}},
    [102] = {[1] = {key = 'Apollyon:E1', display = 'Apollyon Entrance 1'}},
    [103] = {[1] = {key = 'Apollyon:E2', display = 'Apollyon Entrance 2'}},
    [104] = {[11] = {key = 'Apollyon:NW1', display = 'Apollyon Northwest 1'}},
    [105] = {[12] = {key = 'Apollyon:NW2', display = 'Apollyon Northwest 2'}},
    [106] = {[13] = {key = 'Apollyon:NW3', display = 'Apollyon Northwest 3'}},
    [107] = {[14] = {key = 'Apollyon:NW4', display = 'Apollyon Northwest 4'}},
    [108] = {[15] = {key = 'Apollyon:NW5', display = 'Apollyon Northwest 5'}},
    [109] = {[21] = {key = 'Apollyon:SW1', display = 'Apollyon Southwest 1'}},
    [110] = {[22] = {key = 'Apollyon:SW2', display = 'Apollyon Southwest 2'}},
    [111] = {[23] = {key = 'Apollyon:SW3', display = 'Apollyon Southwest 3'}},
    [112] = {[24] = {key = 'Apollyon:SW4', display = 'Apollyon Southwest 4'}},
    [113] = {[31] = {key = 'Apollyon:NE1', display = 'Apollyon Northeast 1'}},
    [114] = {[32] = {key = 'Apollyon:NE2', display = 'Apollyon Northeast 2'}},
    [115] = {[33] = {key = 'Apollyon:NE3', display = 'Apollyon Northeast 3'}},
    [116] = {[34] = {key = 'Apollyon:NE4', display = 'Apollyon Northeast 4'}},
    [117] = {[35] = {key = 'Apollyon:NE5', display = 'Apollyon Northeast 5'}},
    [118] = {[41] = {key = 'Apollyon:SE1', display = 'Apollyon Southeast 1'}},
    [119] = {[42] = {key = 'Apollyon:SE2', display = 'Apollyon Southeast 2'}},
    [120] = {[43] = {key = 'Apollyon:SE3', display = 'Apollyon Southeast 3'}},
    [121] = {[44] = {key = 'Apollyon:SE4', display = 'Apollyon Southeast 4'}},
}

local function default_announce(message)
    windower.add_to_chat(123, message)
end

function FloorDetector.new(opts)
    opts = opts or {}
    local self = {}

    self.logger = opts.logger
    self.debug_enabled = opts.debug_enabled or function() return false end
    self.should_handle_reports = opts.handle_reports or function() end
    self.announce = opts.announce or default_announce

    self.history = {}
    self.last_floor = nil
    self.position_active = false
    self.position_attempts = 0

    return setmetatable(self, {__index = FloorDetector})
end

function FloorDetector:reset()
    self.last_floor = nil
    self.position_active = false
    self.position_attempts = 0
    for key in pairs(self.history) do
        self.history[key] = nil
    end
end

function FloorDetector:log(message)
    if self.logger and self.debug_enabled() then
        self.logger:log(message)
    end
end

function FloorDetector:announce_once(history_key, message)
    if self.history[history_key] then
        return false
    end
    self.history[history_key] = true
    if self.debug_enabled() then
        self.announce(message)
    end
    self.position_active = false
    return true
end

function FloorDetector:detect_by_status(packet)
    if not packet then
        return
    end

    if packet:unpack('H', 0x24 + 1) ~= 2 then
        return
    end

    for i = 0, 4 do
        local floor_value = packet:unpack('H', 0x14 * i + 0x28 + 1)
        local floor_str = packet:unpack('z', 0x14 * i + 0x2C + 1)
        if floor_str ~= '' then
            local is_floor_indicator = floor_str:find('_Floor_', 1, true) and floor_str:find('#', 1, true)
            if is_floor_indicator and (not self.history[floor_str] or self.history[floor_str] ~= floor_value) then
                self.history[floor_str] = floor_value
                local history_key = string.format('status:%s:%s', floor_str, tostring(floor_value))
                local message = string.format('%s: %d', floor_str, floor_value)
                if self:announce_once(history_key, message) then
                    self.last_floor = floor_str
                    self.should_handle_reports('floor')
                end
            end
        end
    end
end

function FloorDetector:arm_position_detection()
    self.position_active = true
    self.position_attempts = 0
    coroutine.schedule(function() self:detect_by_position() end, 0.1)
    coroutine.schedule(function() self:detect_by_position() end, 0.3)
    coroutine.schedule(function() self:detect_by_position() end, 0.6)
end

function FloorDetector:detect_by_menu(packet)
    local parsed = packets.parse('incoming', packet)
    if not parsed then
        return
    end

    local menu_id = parsed['Menu ID']
    local option_index = parsed['Option Index']

    if menu_id and option_index then
        local by_menu = floor_menu_lookup[menu_id]
        local floor_info = by_menu and by_menu[option_index]
        if floor_info then
            local history_key = string.format('menu:%s:%d', floor_info.key, option_index)
            local message = string.format('FLOOR DETECTED! %s', floor_info.display)
            if self:announce_once(history_key, message) then
                self.last_floor = floor_info.key
                self.should_handle_reports('floor')
            end
        end
    end

    self:arm_position_detection()
end

function FloorDetector:detect_by_position()
    if not self.position_active then
        return
    end

    local player = windower.ffxi.get_mob_by_target('me') or windower.ffxi.get_player()
    if not player or not player.x or not player.y or not player.z then
        return
    end

    local zone_id = player.zone or (windower.ffxi.get_info() or {}).zone
    local zone_data = floor_zones[zone_id]
    if not zone_data then
        return
    end

    for _, entry in ipairs(zone_data.positions) do
        local dx = player.x - entry.x
        local dy = player.y - entry.y
        local dz = player.z - entry.z
        local dist_sq = dx * dx + dy * dy + dz * dz
        if dist_sq <= (entry.radius_sq or zone_data.radius_sq or 900) then
            if self.last_floor ~= entry.key then
                self.last_floor = entry.key
                local history_key = string.format('pos:%s', entry.key)
                local message = string.format('FLOOR DETECTED! %s', entry.display)
                if self:announce_once(history_key, message) then
                    self:log(string.format('Position floor detect: %s (dist^2=%.2f | player=(%.2f, %.2f, %.2f))',
                        entry.key, dist_sq, player.x, player.y, player.z))
                    self.should_handle_reports('floor')
                end
            end
            return
        end
    end

    self.position_attempts = self.position_attempts + 1
    if self.position_attempts > 10 then
        self.position_active = false
        self:log(string.format('Position detection timeout at (%.2f, %.2f, %.2f)', player.x, player.y, player.z))
    else
        self:log(string.format('Position check attempt %d no match: (%.2f, %.2f, %.2f)',
            self.position_attempts, player.x, player.y, player.z))
    end
end

local temenos_tower_map = {
    N = 'northern',
    W = 'western',
    E = 'eastern',
    C = 'central',
    NORTHERN = 'northern',
    WESTERN = 'western',
    EASTERN = 'eastern',
    CENTRAL = 'central',
}

local apollyon_tower_map = {
    NW = 'nw',
    NE = 'ne',
    SW = 'sw',
    SE = 'se',
    NORTHWEST = 'nw',
    NORTHEAST = 'ne',
    SOUTHWEST = 'sw',
    SOUTHEAST = 'se',
    ENTRANCE = 'entrance',
}

local function parse_floor_key(zone_id, key)
    if not key then
        return nil
    end

    local function build_context(area, tower, floor)
        if not area or not tower then
            return nil
        end
        return {
            area = area,
            tower = tower,
            floor = floor or 0,
        }
    end

    local function entrance_context()
        if zone_id == 37 then
            return build_context('temenos', 'entrance', 0)
        elseif zone_id == 38 then
            return build_context('apollyon', 'entrance', 0)
        end
    end

    local zone_name, suffix = key:match('([^:]+):(.+)')
    if not zone_name or not suffix then
        local simple_tag, simple_floor = key:match('^([%a]+)_Floor_#?(%d+)$')
        if simple_tag and simple_floor then
            local tag_upper = simple_tag:upper()
            local area
            local tower_key

            if zone_id == 37 then
                area = 'temenos'
                tower_key = temenos_tower_map[tag_upper]
            elseif zone_id == 38 then
                area = 'apollyon'
                tower_key = apollyon_tower_map[tag_upper]
            else
                tower_key = temenos_tower_map[tag_upper] or apollyon_tower_map[tag_upper]
                if tower_key == 'nw' or tower_key == 'ne' or tower_key == 'sw' or tower_key == 'se' then
                    area = 'apollyon'
                elseif tower_key then
                    area = 'temenos'
                end
            end

            local floor = tonumber(simple_floor)
            if tower_key == 'entrance' then
                floor = 0
            end
            if area and tower_key and floor then
                return build_context(area, tower_key, floor)
            end
        else
            local tag_upper = key:upper()
            if tag_upper:find('ENTRANCE', 1, true) then
                return entrance_context()
            end
        end

        return entrance_context()
    end

    local area
    local tower_key
    local floor_str

    if zone_id == 37 or zone_name == 'Temenos' then
        area = 'temenos'
        tower_key, floor_str = suffix:match('(%a+)(%d+)')
        if tower_key then
            tower_key = temenos_tower_map[tower_key:upper()]
        end
    elseif zone_id == 38 or zone_name == 'Apollyon' then
        area = 'apollyon'
        tower_key, floor_str = suffix:match('(%a+)(%d+)')
        if tower_key then
            tower_key = apollyon_tower_map[tower_key:upper()]
        end
    end

    local floor = tonumber(floor_str)
    if tower_key == 'entrance' then
        floor = 0
    end

    if area and tower_key and floor then
        return build_context(area, tower_key, floor)
    end

    if suffix and suffix:upper():find('ENTRANCE', 1, true) then
        return entrance_context()
    end

    return nil
end

local function position_floor_context()
    local player = windower.ffxi.get_mob_by_target('me') or windower.ffxi.get_player()
    if not player or not player.x or not player.y or not player.z then
        return nil
    end

    local zone_id = player.zone or (windower.ffxi.get_info() or {}).zone
    local zone_data = floor_zones[zone_id]
    if not zone_data then
        return nil
    end

    local best_entry
    local best_dist_sq = math.huge

    for _, entry in ipairs(zone_data.positions) do
        local dx = player.x - entry.x
        local dy = player.y - entry.y
        local dz = player.z - entry.z
        local dist_sq = dx * dx + dy * dy + dz * dz
        local radius_sq = entry.radius_sq or zone_data.radius_sq or 900
        if dist_sq <= radius_sq and dist_sq < best_dist_sq then
            best_entry = entry
            best_dist_sq = dist_sq
        end
    end

    if best_entry then
        return parse_floor_key(zone_id, best_entry.key)
    end

    return nil
end

function FloorDetector:get_floor_context()
    local zone_info = windower.ffxi.get_info()
    local zone_id = zone_info and zone_info.zone

    if not zone_id then
        return nil
    end

    local context = position_floor_context()
    if context then
        return context
    end

    if self.last_floor then
        return parse_floor_key(zone_id, self.last_floor)
    end
end

return FloorDetector
