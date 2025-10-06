require('luau')
local api = require('util/api')
local util_data = require('util/data')
local formatter = require('util/format')
local M = {}

function M.handle_addon_command(command, args, displaybox, settings)
    command = command and command:lower()
    local zone_info = windower.ffxi.get_info()
    local zone_id = zone_info.zone
    local in_limbus = (zone_id == 37 or zone_id == 38)

    if not command or command == '' then
        local reports = api.get_latest_reports(windower.ffxi.get_info().server, settings.display_limit)
        windower.add_to_chat(123, util_data.format_box_display(reports))
        return
    elseif command == 'hud' then
        if displaybox:visible() then
            displaybox:hide()
        else
            local reports = api.get_latest_reports(windower.ffxi.get_info().server, settings.display_limit)
            displaybox.nm_info = util_data.format_box_display(reports)
            displaybox:show()
        end
        return
    elseif command == 'help' then
        windower.add_to_chat(180, '[WhereIsNM] Commands:')
        windower.add_to_chat(180, '//nm send - Enable/disable auto-reporting')
        windower.add_to_chat(180, '//nm hud - Toggle HUD display')
        windower.add_to_chat(180, '//nm tod <job_or_name> - Report TOD (in Limbus)')
        windower.add_to_chat(180, '//nm tod <zone> <job_or_name> - Report TOD (outside Limbus)')
        return
    end
end

return M
