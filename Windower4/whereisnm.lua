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
v0.0.7 : Added queue system for batch reporting to eliminate gameplay performance impact.
         Removed redundant manual report command.
         Added automatic TOD detection and manual TOD reporting commands.
---------------------------------------------------------------------------
]]

require('luau')
texts = require('texts')
res = require('resources')
config = require('config')
api = require('api')
util_data = require('utils')
queue = require('queue')

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
                    queue.queue_spawn_report(area, tower, floor, 'nm', mob.name, mob.id)
                end
            elseif mob.spawn_type == 2 then
                local area, tower, floor = util_data.parse_floor_to_api_format(current_floor, zone_id)
                if area and tower and floor then
                    queue.queue_spawn_report(area, tower, floor, 'question', nil, mob.id)
                end
            end
        end
    end
end

function tod_monitor_loop()
    util_data.check_and_track_tod(current_floor)
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

-- Send queued reports when leaving Limbus
windower.register_event('zone change', function(new_id, old_id)
    if (old_id == 37 or old_id == 38) and (new_id ~= 37 and new_id ~= 38) then
        queue.load_queue()
        coroutine.schedule(queue.send_queued_reports, 2)
    end
end)

windower.register_event('addon command', function(command, ...)
    command = command and command:lower()
    local args = L{...}

    if not command or command == '' then
        local reports = api.get_latest_reports(windower.ffxi.get_info().server)
        windower.add_to_chat(123, format_box_display(reports))
        return
    
    elseif command == 'send' then
        auto_send = not auto_send
        local status = auto_send and 'enabled' or 'disabled'
        windower.add_to_chat(123, string.format('[%s] Auto-reporting %s', _addon.name, status))
        return

    elseif command == 'hud' then
        if displaybox:visible() then
            displaybox:hide()
            auto_refresh_enabled = false
            windower.add_to_chat(123, string.format('[%s] HUD hidden', _addon.name))
        else
            local reports = api.get_latest_reports(windower.ffxi.get_info().server)
            displaybox.nm_info = format_box_display(reports)
            displaybox:show()
            auto_refresh_enabled = true
            windower.add_to_chat(123, string.format('[%s] HUD visible', _addon.name))
        end
        return

    elseif command == 'tod' then
        local zone_info = windower.ffxi.get_info()
        local zone_id = zone_info.zone
        local in_limbus = (zone_id == 37 or zone_id == 38)
        
        -- Determine if we have zone parameter or not
        local zone_param, job_or_name
        
        if in_limbus then
            -- In Limbus: //nm tod <job_or_name>
            if #args == 0 then
                windower.add_to_chat(123, '[WhereIsNM] Usage: //nm tod <job_or_name>')
                return
            end
            job_or_name = args:concat(' ')
            
            -- Auto-detect zone from current location
            if zone_id == 37 then
                zone_param = 'temenos'
            elseif zone_id == 38 then
                zone_param = 'apollyon'
            end
        else
            -- Outside Limbus: //nm tod <zone> <job_or_name>
            if #args < 2 then
                windower.add_to_chat(123, '[WhereIsNM] Usage: //nm tod <zone> <job_or_name>')
                return
            end
            zone_param = args[1]:lower()
            table.remove(args, 1)
            job_or_name = args:concat(' ')
            
            -- Validate zone
            if zone_param ~= 'temenos' and zone_param ~= 'apollyon' then
                windower.add_to_chat(123, '[WhereIsNM] Invalid zone. Use "temenos" or "apollyon"')
                return
            end
        end
        
        -- Call API to submit manual TOD report
        api.submit_tod_report(zone_param, nil, nil, nil, job_or_name)
        return

    elseif command == 'help' then 
        windower.add_to_chat(180, string.format('[%s] Commands:', _addon.name))
        windower.add_to_chat(180, '//nm send - Enable/disable auto-reporting')
        windower.add_to_chat(180, '//nm hud - Toggle HUD display')
        windower.add_to_chat(180, '//nm tod <job_or_name> - Report TOD (in Limbus)')
        windower.add_to_chat(180, '//nm tod <zone> <job_or_name> - Report TOD (outside Limbus)')
        return

    else
        windower.add_to_chat(123, string.format('[%s] Unknown command. Use //nm help', _addon.name))
    end
end)

function auto_send_loop()
    if auto_send then
        findTarget_and_sendReport()
    end
end

auto_send_loop:loop(3)
tod_monitor_loop:loop(2)