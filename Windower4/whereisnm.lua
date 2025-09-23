_addon.name = 'WhereIsNM'
_addon.author = 'Mandracord Team'
_addon.version = '0.0.6'
_addon.commands = {'nm','whereisnm'}

require('luau')
require('strings')
require('logger')
texts = require('texts')
res = require('resources')
config = require('config')
api = require('api')

--[[
Changelog

v0.0.1 : First release
v0.0.2 : Minor updates
v0.0.3 : Added TOD reporting
v0.0.4 : Added version checking
v0.0.5 : Added <t> target support, fixed //nm command to clearly display if a NM was killed XX:XX ago.
v0.0.6 : Added delete command for own reports (if you need to correct a incorrect report).

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
local displaybox = texts.new('${nm_info}', settings.text, settings)
local last_reports = ""
local auto_refresh_enabled = false

-------------------------------------------------------------------------
-- DO NOT EDIT BELOW
-------------------------------------------------------------------------

function check_addon()
    local result = api.check_version(_addon.version)
    if result then
        windower.add_to_chat(123, string.format('[%s] %s', _addon.name, result))
    end
end


windower.register_event('load','login',function ()
    check_addon()
    if windower.ffxi.get_info().logged_in then
        windower.add_to_chat(123, string.format('[%s] Thank you for using WhereIsNM! Use //nm to get the latest update.', _addon.name))
    end
end)

function parse_zone_args(area_arg, tower_arg, floor)
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
    
    local area = area_map[area_arg and area_arg:lower()]
    local tower = tower_map[tower_arg and tower_arg:lower()]
    
    return area, tower, floor
end

function format_box_display(reports_text)
    if not reports_text or reports_text == "Unable to fetch latest reports" then
        return "No recent data"
    end
    
    local lines = {}
    local current_type = ""
    
    for line in reports_text:gmatch("[^\r\n]+") do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        
        if line:match("Reported NM") then
            current_type = "[NM] "
        elseif line:match("Reported %?%?%?") then
            current_type = "[???] "
        elseif line ~= "" and not line:match("Recent spawns") and not line:match("Reported") then
            if current_type ~= "" then
                table.insert(lines, current_type .. line)
            else
                table.insert(lines, line)
            end
        end
    end
    
    if #lines == 0 then
        return "No recent data"
    end
    
    return table.concat(lines, "\n")
end

windower.register_event('addon command', function(command, ...)
    command = command and command:lower()
    local args = L{...}
    
    if command == 'report' then
        local spawn_type = 'question'
        local area, tower, floor, enemy_input
        local zone_info = windower.ffxi.get_info()
        local zone_name = res.zones[zone_info.zone] and res.zones[zone_info.zone].en or 'Unknown Zone'

        if not (zone_name:find("Temenos") or zone_name:find("Apollyon")) then
            windower.add_to_chat(123, 'You must be in Limbus (Temenos or Apollyon) to report NM or ???.')
            return
        end

        if args[1] and args[1]:lower() == 'nm' then
            spawn_type = 'nm'
            if args[2] and args[3] and args[4] and args[5] then
                enemy_input = args[2]
                area, tower = parse_zone_args(args[3], args[4])
                floor = tonumber(args[5])
                if not floor then
                    windower.add_to_chat(123, 'Invalid floor number.')
                    return
                end
            else
                windower.add_to_chat(123, 'Usage: //nm report nm <job/name> <area> <tower> <floor>')
                return
            end
        elseif args[1] and args[1]:lower() == 'tod' then
            if args[2] and args[3] and args[4] and args[5] then
                enemy_input = args[2]
                area, tower = parse_zone_args(args[3], args[4])
                floor = tonumber(args[5])
                if not floor then
                    windower.add_to_chat(123, 'Invalid floor number.')
                    return
                end
            elseif args[2] and args[3] and args[4] then
                area, tower = parse_zone_args(args[2], args[3])
                floor = tonumber(args[4])
                if not floor then
                    windower.add_to_chat(123, 'Invalid floor number.')
                    return
                end
            else
                windower.add_to_chat(123, 'Usage: //nm report tod <job/name> <area> <tower> <floor>')
                return
            end
            
            if not area or not tower then
                windower.add_to_chat(123, 'Invalid area or sector specified.')
                return
            end
            
            api.submit_tod_report(area, tower, floor, enemy_input)
            return
        else
            if args[1] and args[2] and args[3] then
                floor = tonumber(args[3])
                if not floor then
                    windower.add_to_chat(123, 'Invalid floor number.')
                    return
                end
                area, tower = parse_zone_args(args[1], args[2], floor)
            else
                windower.add_to_chat(123, 'Required data missing. Try again.')
                return
            end
        end
        
        if not area or not tower then
            windower.add_to_chat(123, 'Invalid area or sector specified.')
            return
        end
        
        api.submit_report(area, tower, floor, spawn_type, enemy_input)
        
    elseif command == 'delete' then
        if args[1] and args[2] and args[3] then
            local area, tower = parse_zone_args(args[1], args[2])
            local floor = tonumber(args[3])
            
            if not floor then
                windower.add_to_chat(123, 'Invalid floor number.')
                return
            end
            
            if not area or not tower then
                windower.add_to_chat(123, 'Invalid area or sector specified.')
                return
            end
            
            api.delete_report(area, tower, floor)
        else
            windower.add_to_chat(123, 'Usage: //nm delete <area> <tower> <floor>')
            windower.add_to_chat(123, 'Example: //nm delete t central 5')
            return
        end
        
    elseif command == 'show' then
        local reports = api.get_latest_reports(windower.ffxi.get_info().server)
        last_reports = reports
        displaybox.nm_info = format_box_display(reports)
        displaybox:show()
        auto_refresh_enabled = true
        windower.add_to_chat(123, 'WhereIsNM Displaybox shown')
        
    elseif command == 'hide' then
        displaybox:hide()
        auto_refresh_enabled = false
        windower.add_to_chat(123, 'WhereIsNM Displaybox hidden')

    elseif command == 'help' then 
        windower.add_to_chat(180,'[WhereIsNM] Command prefix //nm or //whereisnm:')
        windower.add_to_chat(180,'Each report has some data requirements: <zone> <tower/sector> <floor>')
        windower.add_to_chat(180,'For ??? spawns: //nm report t central 2 (Temenos central floor 2)')
        windower.add_to_chat(180,'For NM spawns: //nm report nm war t central 2 (Warrior NM at Temenos central floor 2)')
        windower.add_to_chat(180,'For TOD reports: //nm report tod war t central 2 (Kill Warrior NM at location)')
        windower.add_to_chat(180,'To delete your own reports: //nm delete t central 2 (Delete your report at location)')
        windower.add_to_chat(180,'It is possible to use both full name or shortcut as t for Temenos, c for central.')
        windower.add_to_chat(180,'See the readme or www.whereisnm.com for a full list.')
        windower.add_to_chat(180,'------------------------------------------')
    else
        windower.add_to_chat(123, api.get_latest_reports(windower.ffxi.get_info().server))
    end
end)

-- Auto-refresh the display 
windower.register_event('time change', function(new, old)
    if auto_refresh_enabled and displaybox:visible() and new % 60 == 0 then
        local reports = api.get_latest_reports(windower.ffxi.get_info().server)
        if reports ~= last_reports then
            last_reports = reports
            displaybox.nm_info = format_box_display(reports)
        end
    end
end)