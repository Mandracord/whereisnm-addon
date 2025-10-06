require('luau')
require('strings')
local api = require('util/api')
local util_data = require('util/data')
local formatter = require('util/format')

local M = {}

function M.handle_addon_command(command, args, displaybox, settings)
    command = command and command:lower()

    if not command or command == '' then
        local reports = api.get_latest_reports(windower.ffxi.get_info().server, settings.display_limit)
        windower.add_to_chat(123, util_data.format_box_display(reports))
        return

    elseif command == 'send' then
        settings.auto_send = not settings.auto_send
        settings:save()
        local status = settings.auto_send and 'enabled' or 'disabled'
        windower.add_to_chat(123, string.format('[WhereIsNM] reporting %s', status))
        return

    elseif command == 'hud' then
        if displaybox:visible() then
            displaybox:hide()
            windower.add_to_chat(123, string.format('[WhereIsNM] HUD hidden', _addon.name))
        else
            local reports = api.get_latest_reports(windower.ffxi.get_info().server, settings.display_limit)
            displaybox.nm_info = util_data.format_box_display(reports)
            displaybox:show()
            windower.add_to_chat(123, string.format('[WhereIsNM] HUD visible', _addon.name))
        end
        return

    elseif command == 'tod' then
        local zone_info = windower.ffxi.get_info()
        local zone_id = zone_info.zone
        local in_limbus = (zone_id == 37 or zone_id == 38)

        local zone_param, job_or_name

        if in_limbus then
            if #args == 0 then
                windower.add_to_chat(123, '[WhereIsNM] Usage: //nm tod <job_or_name>')
                return
            end
            job_or_name = args:concat(' ')
            job_or_name = windower.convert_auto_trans(job_or_name)

            if zone_id == 37 then
                zone_param = 'temenos'
            elseif zone_id == 38 then
                zone_param = 'apollyon'
            end
        else
            if #args < 2 then
                windower.add_to_chat(123, '[WhereIsNM] Usage: //nm tod <zone> <job_or_name>')
                return
            end
            zone_param = args[1]:lower()
            zone_param = windower.convert_auto_trans(zone_param):lower()
            table.remove(args, 1)
            job_or_name = args:concat(' ')
            job_or_name = windower.convert_auto_trans(job_or_name)

            if zone_param ~= 'temenos' and zone_param ~= 'apollyon' then
                windower.add_to_chat(123, string.format('[WhereIsNM] Invalid zone. Use "%s" or "%s"',
                    formatter.format_location_name('temenos'), formatter.format_location_name('apollyon')))
                return
            end
        end

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
end

return M
