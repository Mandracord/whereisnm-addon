require('luau')

local M = {}

function M.handle_addon_command(command, args, deps)
    command = command and command:lower()

    local logger = deps.logger
    local scanner = deps.scanner
    local queue = deps.queue
    local api = deps.api
    local settings = deps.settings
    local settings_file = deps.settings_file
    local handle_pending_reports = deps.handle_pending_reports
    local debug_enabled = deps.debug_enabled or function() return false end
    local displaybox = deps.displaybox
    local function refresh_hud_if_active()
        if not (settings and settings.hud and displaybox and displaybox.show and api) then
            return
        end
        local limit = (settings.display_limit) or 10
        local report_text = api:get_latest_reports(nil, limit)
        if report_text then
            displaybox.nm_info = report_text
        end
        displaybox:show()
    end

    if command == 'send' then
        local previous = settings.send
        settings.send = not settings.send
        settings_file.save(settings)
        local status = settings.send and 'Enabled' or 'Disabled'
        local status_message
        if settings.send then
            status_message = string.format('[WhereIsNM] Sending Limbus data: %s. Thank you for contributing!', status)
        else
            status_message = string.format('[WhereIsNM] Sending Limbus data: %s.', status)
        end
        windower.add_to_chat(123, status_message)

        if settings.send and not previous then
            queue.load_queue()
            handle_pending_reports()
            scanner.trigger_scan()
        end

        return
    end

    if not command or command == '' then
        if api then
            local limit = (settings and settings.display_limit) or 10
            local report_text = api:get_latest_reports(nil, limit)

            if displaybox then
                displaybox.nm_info = report_text
                if settings and settings.hud and displaybox.show then
                    displaybox:show()
                elseif settings and not settings.hud and displaybox.hide then
                    displaybox:hide()
                end
            end

            local hud_enabled = settings and settings.hud and displaybox ~= nil
            if not hud_enabled then
                for line in report_text:gmatch('[^\r\n]+') do
                    windower.add_to_chat(123, line)
                end
            end
        end

        return
        
    elseif command == 'submit' then
        local cmd = args[1] and args[1]:lower()
        
        if not cmd then 
            windower.add_to_chat(123, '[WhereIsNM] Unknown command. Use //nm help')
            return
        end

        local function normalize_state(flag, default_value)
            if flag == nil then
                return default_value
            end
            return flag
        end

        if cmd == 'floor' then
            local action = args[2] and args[2]:lower()
            local current = normalize_state(settings.submit_on_floor_change, true)
            local new_state
            if action == 'on' or action == 'enable' or action == 'true' then
                new_state = true
            elseif action == 'off' or action == 'disable' or action == 'false' then
                new_state = false
            else
                new_state = not current
            end

            settings.submit_on_floor_change = new_state
            if settings_file then settings_file.save(settings) end

            local state_text = new_state and 'Enabled' or 'Disabled'
            windower.add_to_chat(123,
                string.format('[WhereIsNM] Submit on floor change: %s.', state_text))
            if debug_enabled() then
                logger:log(string.format('submit_on_floor_change set to %s', tostring(new_state)))
            end
            return
        end

    elseif command == 'hud' then
        if not settings then
            windower.add_to_chat(123, '[WhereIsNM] HUD settings unavailable.')
            return
        end

        local action = args[1] and args[1]:lower()
        if action == 'show' or action == 'on' then
            settings.hud = true
        elseif action == 'hide' or action == 'off' then
            settings.hud = false
        else
            settings.hud = not settings.hud
        end

        if settings_file then settings_file.save(settings) end

        if displaybox then
            if settings.hud and displaybox.show then
                if api then
                    local limit = (settings and settings.display_limit) or 10
                    local report_text = api:get_latest_reports(nil, limit)
                    if report_text then
                        displaybox.nm_info = report_text
                    end
                end
                displaybox:show()
            elseif not settings.hud and displaybox.hide then
                displaybox:hide()
            end
        end

        local state_text = settings.hud and 'Enabled' or 'Disabled'
        windower.add_to_chat(123, string.format('[WhereIsNM] HUD %s.', state_text))
        return
    elseif command == 'display' then
        if not settings then
            windower.add_to_chat(123, '[WhereIsNM] Settings unavailable.')
            return
        end

        local category = args[1] and args[1]:lower()
        if category == 'expired' or category == 'dead' then
            local action = args[2] and args[2]:lower()
            local current = settings.include_dead == nil and false or settings.include_dead
            local new_state
            if action == 'on' or action == 'enable' or action == 'true' then
                new_state = true
            elseif action == 'off' or action == 'disable' or action == 'false' then
                new_state = false
            else
                new_state = not current
            end

            settings.include_dead = new_state
            if settings_file then settings_file.save(settings) end

            local state_text = new_state and 'Enabled' or 'Disabled'
            windower.add_to_chat(123,
                string.format('[WhereIsNM] Include expired reports: %s.', state_text))
            if debug_enabled() then
                logger:log(string.format('include_dead set to %s', tostring(new_state)))
            end
            refresh_hud_if_active()
            return
        end

        windower.add_to_chat(123, '[WhereIsNM] Unknown display option. Try //nm display expired on|off.')
        return

    elseif command == 'expired' or command == 'dead' then
        if not settings then
            windower.add_to_chat(123, '[WhereIsNM] Settings unavailable.')
            return
        end

        local action = args[1] and args[1]:lower()
        local current = settings.include_dead == nil and false or settings.include_dead
        local new_state
        if action == 'on' or action == 'enable' or action == 'true' then
            new_state = true
        elseif action == 'off' or action == 'disable' or action == 'false' then
            new_state = false
        else
            new_state = not current
        end

        settings.include_dead = new_state
        if settings_file then settings_file.save(settings) end

        local state_text = new_state and 'Enabled' or 'Disabled'
        windower.add_to_chat(123,
            string.format('[WhereIsNM] Include expired reports: %s.', state_text))
        if debug_enabled() then
            logger:log(string.format('include_dead set to %s', tostring(new_state)))
        end
        refresh_hud_if_active()
        return
    elseif command == 'debug' then
        if not settings then
            windower.add_to_chat(123, '[WhereIsNM] Settings unavailable.')
            return
        end

        local action = args[1] and args[1]:lower()
        local current = settings.debug == true
        local new_state

        if action == 'on' or action == 'enable' or action == 'true' then
            new_state = true
        elseif action == 'off' or action == 'disable' or action == 'false' then
            new_state = false
        else
            new_state = not current
        end

        settings.debug = new_state
        if logger and logger.set_enabled then
            logger:set_enabled(new_state)
        end
        if settings_file then settings_file.save(settings) end

        local state_text = new_state and 'Enabled' or 'Disabled'
        windower.add_to_chat(123, string.format('[WhereIsNM] Debug logging %s.', state_text))
        if new_state and not current and logger then
            logger:log('Debug logging enabled')
        end
        return
    elseif command == 'status' then
        if not settings then
            windower.add_to_chat(123, '[WhereIsNM] Settings unavailable.')
            return
        end

        local function enabled_disabled(flag)
            return flag and 'Enabled' or 'Disabled'
        end

        local function setting_enabled(flag, default_value)
            if flag == nil then
                return default_value
            end
            return flag
        end

        local send_state = enabled_disabled(setting_enabled(settings.send, true))
        local debug_state = enabled_disabled(settings.debug == true)
        local hud_state = enabled_disabled(settings.hud == true)
        local include_dead_state = enabled_disabled(settings.include_dead == true)
        local submit_zone_state = enabled_disabled(setting_enabled(settings.submit_on_zone_change, true))
        local submit_floor_state = enabled_disabled(setting_enabled(settings.submit_on_floor_change, true))
        local spawn_queue = queue.get_spawn_queue_count and queue.get_spawn_queue_count() or 0
        local tod_queue = queue.get_tod_queue_count and queue.get_tod_queue_count() or 0

        windower.add_to_chat(123, '[WhereIsNM] Status:')
        windower.add_to_chat(123, '[WhereIsNM] Status:')
        windower.add_to_chat(123, '================================')
        windower.add_to_chat(123, string.format('Send: %s', send_state))
        windower.add_to_chat(123, string.format('Debug logging: %s', debug_state))
        windower.add_to_chat(123, string.format('HUD: %s', hud_state))
        windower.add_to_chat(123, string.format('Display dead/expired: %s', include_dead_state))
        windower.add_to_chat(123, string.format('Submit on zone change: %s', submit_zone_state))
        windower.add_to_chat(123, string.format('Submit on floor change: %s', submit_floor_state))
        windower.add_to_chat(123, string.format('Pending reports queued: spawn=%d, tod=%d', spawn_queue, tod_queue))
        return

    elseif command == 'help' then
        windower.add_to_chat(180, '[WhereIsNM] Commands:')
        windower.add_to_chat(180, '//nm')
        windower.add_to_chat(180, 'Show latest reports')
        windower.add_to_chat(180,'\n')
        windower.add_to_chat(180,'//nm display expired|dead')
        windower.add_to_chat(180,'Toggle including expired or dead in reports\n')
        windower.add_to_chat(180,'\n')
        windower.add_to_chat(180, '//nm submit floor')
        windower.add_to_chat(180,'Toggle sending on floor change\n')
        windower.add_to_chat(180,'//nm display expired|dead')
        windower.add_to_chat(180,'Toggle including expired or dead in reports\n')
        windower.add_to_chat(180,'\n')
        windower.add_to_chat(180, '//nm hud')
        windower.add_to_chat(180,'Toggle HUD display')
        windower.add_to_chat(180,'\n')
        windower.add_to_chat(180, '//nm debug on|off')
        windower.add_to_chat(180,'Toggle debug logging')
        windower.add_to_chat(180,'\n')
        windower.add_to_chat(180, '//nm status')
        windower.add_to_chat(180,'Show current configuration and queue counts')
        return
    else
        windower.add_to_chat(123, '[WhereIsNM] Unknown command. Use //nm help')
    end
end

return M
