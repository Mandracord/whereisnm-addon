_addon.name = 'WhereIsNM'
_addon.author = 'Mandracord Team'
_addon.version = '0.0.7'
_addon.commands = {'nm','whereisnm'}

--[[
---------------------------------------------------------------------------
RELEASE NOTES
v0.0.1 : First release
v0.0.2 : Minor updates
v0.0.3 : Added TOD reporting
v0.0.4 : Added version checking
v0.0.5 : Added <t> target support, fixed //nm command to clearly display if a NM was killed XX:XX ago.
v0.0.6 : Added delete command for own reports (if you need to correct a incorrect report).

v0.0.7 : Full refactor of code and libraries:
You can report NM and ??? automatic or with a simplified command //nm report | //nm tod. 
Automatic report toggle with //nm send
---------------------------------------------------------------------------
]]

require('luau')
texts = require('texts')
res = require('resources')
config = require('config')
api = require('api')
util_data = require('utils')

defaults = {}
defaults.text = T{}
defaults.text.font = 'Consolas'
defaults.text.size = 10
defaults.text.bg_alpha = 100
defaults.flags = T{}
defaults.flags.bold = true
defaults.flags.draggable = true
defaults.show_displaybox = true

settings = config.load(defaults)
local displaybox = texts.new('${nm_info}', settings.text, settings)
local auto_refresh_enabled = false
local current_floor = nil
local zoning_in_progress = false
local auto_send = false

windower.register_event('load','login',function ()
    if windower.ffxi.get_info().logged_in then
        windower.add_to_chat(123, '[WhereIsNM] Loaded. Use //nm help for commands.')
    end
end)

---------------------------------------------------------------------------
-- DO NOT EDIT BELOW THIS LINE
---------------------------------------------------------------------------

function check_current_floor()
    local zone_info = windower.ffxi.get_info()
    if not zone_info or (zone_info.zone ~= 37 and zone_info.zone ~= 38) then
        current_floor = nil
        return
    end
    
    local player_info = windower.ffxi.get_player()
    if not player_info then return end
    
    local player_mob = windower.ffxi.get_mob_by_index(player_info.index)
    if not player_mob then return end
    
    local floor_name = util_data.identify_floor(player_mob.x, player_mob.y, player_mob.z, zone_info.zone)
    
    if floor_name ~= current_floor then
        current_floor = floor_name
        if floor_name and auto_send then
            windower.add_to_chat(123, string.format('[WhereIsNM] Entered %s', floor_name))
        end
    end
end

function findTarget_and_sendReport()
    if not current_floor then return end
    
    local zone_info = windower.ffxi.get_info()
    local zone_id = zone_info.zone
    
    if zone_id ~= 37 and zone_id ~= 38 then return end
    
    local mobs = windower.ffxi.get_mob_array()
    
    for i, mob in pairs(mobs) do
        if mob.valid_target then
            if util_data.limbus_nms[zone_id]:contains(mob.name) then
                local area, tower, floor = util_data.parse_floor_to_api_format(current_floor, zone_id)
                if area and tower and floor then
                    api.submit_report(area, tower, floor, 'nm', mob.name, mob.id)
                end
            elseif mob.spawn_type == 2 then
                local area, tower, floor = util_data.parse_floor_to_api_format(current_floor, zone_id)
                if area and tower and floor then
                    api.submit_report(area, tower, floor, 'question', nil, mob.id)
                end
            end
        end
    end
end

windower.register_event('outgoing chunk', function(id, data)
    if id == 0x05C then
        zoning_in_progress = true
    elseif id == 0x05B and zoning_in_progress then
        zoning_in_progress = false
        coroutine.schedule(function()
            check_current_floor()
        end, 2)
    end
end)

windower.register_event('addon command', function(command, ...)
    command = command and command:lower()
    local args = L{...}
    
    if command == 'send' then
        auto_send = not auto_send
        local status = auto_send and 'enabled' or 'disabled'
        windower.add_to_chat(123, '[WhereIsNM] sending data ' .. status)
        return
    elseif command == 'report' then
        findTarget_and_sendReport()
        return
    elseif command == 'hud' then
        if displaybox:visible() then
            displaybox:hide()
            auto_refresh_enabled = false
            windower.add_to_chat(123, '[WhereIsNM] HUD hidden')
        else
            local reports = api.get_latest_reports(windower.ffxi.get_info().server)
            displaybox.nm_info = format_box_display(reports)
            displaybox:show()
            auto_refresh_enabled = true
            windower.add_to_chat(123, '[WhereIsNM] HUD visible')
        end
        return
    elseif command == 'help' then 
        windower.add_to_chat(180,'[WhereIsNM] Commands:')
        windower.add_to_chat(180,'//nm send - Enable/disable sending data')
        windower.add_to_chat(180,'//nm report - Manual submit a sighting (NM or ???)')
        windower.add_to_chat(180,'//nm hud - Toggle hud display')
        return
    else
        windower.add_to_chat(123, '[WhereIsNM] Unknown command. Use //nm help')
    end
end)

function auto_send_loop()
    if auto_send then
        findTarget_and_sendReport()
    end
end

auto_send_loop:loop(3)