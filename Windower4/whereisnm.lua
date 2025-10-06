_addon.name = 'WhereIsNM'
_addon.author = 'Mandracord Team'
_addon.version = '0.0.10-BETA'
_addon.commands = {'nm','whereisnm'}

--[[
--------------------------------------------------------------------------------------------------------------
RELEASE NOTES 
v0.0.1   * First release
v0.0.2   * Minor updates
v0.0.3   * Added TOD reporting
v0.0.4   * Added version checking
v0.0.5   * Added <t> target support, fixed //nm command to clearly display if a NM was killed XX:XX ago.
v0.0.6   * Added delete command for own reports (if you need to correct a incorrect report).

v0.0.7   * Added queue system for batch reporting to eliminate gameplay performance impact.
           Removed redundant manual report command.
           Added automatic TOD detection and manual TOD reporting commands.
           Made addon more modular.

v0.0.8   * Minor bug fixes, added scheduler to not spam the API server based on queue-file. 
           Added a history feature for debugging.

v0.0.9   * Bugfixes to TOD reporting
           Updated HUD formatting to have a consistent layout
           Fixed default settings
v0.0.10  * Fixes to floor detection service to combat false reporting. 
           Some refactoring 
           Future release notes will be at https://whereisnm.com/release-notes
]]
--------------------------------------------------------------------------------------------------------------

require('luau')
texts = require('texts')
res = require('resources')
config = require('config')
api = require('util/api')
util_data = require('util/data')
queue = require('util/queue')
formatter = require('util/format')
findtarget = require('util/findtarget')
commands = require('util/commands')

-------------------------------------------------------------------------------------------------------------

defaults = {}
defaults.text = T{}
defaults.text.bg = {alpha = 70, visible = true}
defaults.text.flags = {bold = true}
defaults.text.padding = 5
defaults.text.text = {
    font='Consolas', 
    size= 11,
    stroke = {width = 1}
}
defaults.flags = T{}
defaults.flags.bold = true
defaults.flags.draggable = true
defaults.show_displaybox = true
defaults.auto_send = true
defaults.display_limit = 10
defaults.debug = false
defaults.send_report_between_floors = true

-------------------------------------------------------------------------------------------------------------

settings = config.load(defaults)
queue.load_queue()
local displaybox = texts.new('${nm_info}', settings.text, settings)
local auto_refresh_enabled = false
local current_floor = nil
local zoning_in_progress = false
local auto_send = settings.auto_send
local reported_mobs = {}

-------------------------------------------------------------------------------------------------------------
-- DO NOT EDIT BELOW THIS LINE
-------------------------------------------------------------------------------------------------------------

windower.register_event('load','login',function ()
    check_addon()
    if windower.ffxi.get_info().logged_in then
        windower.add_to_chat(123, string.format('[%s] Thank you for using WhereIsNM! Use //nm to get the latest update.', _addon.name))
    end
end)

function check_addon()
    local result = api.check_version(_addon.version)
    if result then
        windower.add_to_chat(123, string.format('[%s] %s', _addon.name, result))
    end
end

function check_current_floor()
    floor_check_done = false
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
    end

    floor_check_done = true
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
            findtarget.floor_transition_in_progress = true
            check_current_floor()
            if settings.send_report_between_floors then 
                queue.load_queue()
                queue.send_queued_reports()
                reported_mobs = {}
            end
            findtarget.floor_transition_in_progress = false
        end, 0.5)
    end
end)

windower.register_event('zone change', function(new_id, old_id)
    if (old_id == 37 or old_id == 38) and (new_id ~= 37 and new_id ~= 38) then
        util_data.clear_tod_tracking()
        queue.load_queue()
        coroutine.schedule(queue.send_queued_reports, 2)
    else
        local queue_count = queue.get_queue_count()
        if queue_count > 0 then
            coroutine.schedule(queue.send_queued_reports, 2)
        end
    end
end)

windower.register_event('addon command', function(command, ...)
    local args = L{...}
    commands.handle_addon_command(command, args, displaybox, settings)
end)

function auto_send_loop()
    findtarget.identifyTargets(current_floor, reported_mobs, auto_send)
end

auto_send_loop:loop(2.2)
tod_monitor_loop:loop(1)