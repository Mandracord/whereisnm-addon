_addon.name = 'Whereisnm'
_addon.author = 'Mandracord Team'
_addon.version = '0.0.1'
_addon.commands = {'nm','whereisnm'}

require('luau')
require('strings')
require('logger')
texts = require('texts')
res = require('resources')
config = require('config')
api = require('utils/api')

--[[
Changelog

v0.0.1 : First release, beta testing 

]]

-------------------------------------------------------------------------
-- Default Settings
-------------------------------------------------------------------------

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
local displaybox = texts.new(settings.defaults)

-------------------------------------------------------------------------
-- DO NOT EDIT BELOW
-------------------------------------------------------------------------

windower.register_event('load','login',function ()
    if windower.ffxi.get_info().logged_in then
        windower.add_to_chat(123, string.format('[%s] Thank you for using Whereisnm! Use \\cs(100,255,100)//nm\\cr to get the latest update.', _addon.name))
        coroutine.schedule(login, 5)
    end
end)

function parse_zone_args(area_arg, tower_arg, floor)
    -- Handle abbreviations: tn = temenos north, etc.
    local area_map = {
        t = 'temenos', te = 'temenos', tem = 'temenos', temenos = 'temenos',
        a = 'apollyon', ap = 'apollyon', apo = 'apollyon', apollyon = 'apollyon'
    }
    
    local tower_map = {
        n = 'northern', north = 'northern', northern = 'northern',
        s = 'southern', south = 'southern', southern = 'southern', 
        e = 'eastern', east = 'eastern', eastern = 'eastern',
        w = 'western', west = 'western', western = 'western',
        c = 'central', cent = 'central', central = 'central',
        nw = 'nw', ne = 'ne', sw = 'sw', se = 'se'
    }
    
    local area = area_map[area_arg:lower()]
    local tower = tower_map[tower_arg:lower()]
    
    return area, tower, floor
end

windower.register_event('addon command', function(command, ...)
    command = command and command:lower() or 'help'
    local args = L{...}
    
    if command == 'report' then
        local spawn_type = 'question' -- Default to ??? spawn
        local area, tower, floor
        
        if args[1] and args[1]:lower() == 'nm' then
            spawn_type = 'nm'
            -- Parse: //nm report nm tn 4 or //nm report nm temenos north 4
            if args[2] and args[3] and args[4] then
                area, tower, floor = parse_zone_args(args[2], args[3], tonumber(args[4]))
            else
                windower.add_to_chat(123, 'Usage: //nm report nm <area> <tower> <floor>')
                return
            end
        else
            -- For ??? spawns
            area, tower, floor = parse_zone_args(args[1], args[2], tonumber(args[3]))
            if not area then
                windower.add_to_chat(123, 'Required data missing. Try again.')
                return
            end
        end
        
        api.submit_report(area, tower, floor, spawn_type)
        
    else
        -- Default: show latest spawns
        windower.add_to_chat(123, api.get_latest_location(windower.ffxi.get_info().server))
    end
end)