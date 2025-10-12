require('luau')

local ltn12 = require('ltn12')
local https = require('ssl.https')
local json = require('util.json')
local sha = require('util.sha2')
local formatter = require('util.format')
local files = require('files')
local resources = require('resources')

local Api = {}
Api.__index = Api

local DEFAULT_BASE_URL = 'https://whereisnm.com'
local REPORTS_PATH = '/api/v1/reports'
local SYNC_PATH = '/api/v1/reports/sync'
local TOD_PATH = '/api/v1/reports/tod'
local VERSION_PATH = '/version'
local DEFAULT_ERROR_LOG_PATH = 'data/api_errors.log'
local CLIENT_HEADER = 'WhereIsNM-Addon'

-- Return value for settings.lua 
Api.DEFAULT_BASE_URL = DEFAULT_BASE_URL


local function build_user_agent()
    return string.format('WhereIsNM/%s', _addon.version or 'unknown')
end

---Create a new API client instance.
---@param opts table|nil
---@return table
function Api.new(opts)
    opts = opts or {}

    local base_url = opts.base_url or DEFAULT_BASE_URL

    local instance = {
        base_url = base_url,
        reports_endpoint = opts.reports_endpoint or (base_url .. REPORTS_PATH),
        tod_endpoint = opts.tod_endpoint or (base_url .. TOD_PATH),
        sync_endpoint = opts.sync_endpoint or (base_url .. SYNC_PATH),
        version_url = opts.version_url or (base_url .. VERSION_PATH),
        logger = opts.logger,
        debug_enabled = opts.debug_enabled or function()
            return false
        end,
        formatter = opts.formatter or formatter,
        error_log_path = opts.error_log_path or DEFAULT_ERROR_LOG_PATH,
    }

    return setmetatable(instance, Api)
end

local function to_number_or_nil(value)
    local numeric = tonumber(value)
    return numeric
end

function Api:_debug(message)
    if self.logger and self.debug_enabled() then
        self.logger:log(string.format('[API] %s', message))
    end
end

function Api:_log_error(error_type, details)
    local log_path = self.error_log_path
    local log_file = files.new(log_path, true)
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local player_info = windower.ffxi.get_player()
    local server_info = windower.ffxi.get_info()

    local player_name = player_info and player_info.name or 'Unknown'
    local server_name = 'Unknown'

    if server_info and server_info.server then
        local server = resources.servers[server_info.server]
        if server and server.en then
            server_name = server.en
        end
    end

    local log_entry = string.format('[%s] %s | Player: %s | Server: %s | Details: %s\n', timestamp, error_type,
        player_name, server_name, details)

    log_file:append(log_entry)

    if self.logger then
        self.logger:log(string.format('[API:%s] %s', error_type, details))
    end
end

function Api:_request(method, url, payload, extra_headers)
    local body_string
    if payload then
        if type(payload) == 'table' then
            local ok, encoded = pcall(json.encode, payload)
            if not ok then
                self:_log_error('JSON_ENCODE_ERROR', tostring(encoded))
                return false, nil, nil
            end
            body_string = encoded
        elseif type(payload) == 'string' then
            body_string = payload
        else
            self:_log_error('REQUEST_PAYLOAD_ERROR', 'Unsupported payload type: ' .. type(payload))
            return false, nil, nil
        end
    end

    local headers = {
        ['User-Agent'] = build_user_agent(),
        ['X-Client-Type'] = CLIENT_HEADER,
    }

    if body_string then
        headers['Content-Type'] = 'application/json'
        headers['Content-Length'] = tostring(#body_string)
    end

    if extra_headers then
        for key, value in pairs(extra_headers) do
            headers[key] = value
        end
    end

    local response_body = {}

    local ok, status_code, _, status_line = https.request({
        url = url,
        method = method,
        headers = headers,
        source = body_string and ltn12.source.string(body_string) or nil,
        sink = ltn12.sink.table(response_body),
    })

    local response_text = table.concat(response_body)
    local numeric_status = to_number_or_nil(status_code)

    if not ok then
        self:_log_error('HTTP_ERROR', string.format('%s %s failed: %s', method, url, status_line or 'unknown'))
        return false, numeric_status, response_text
    end

    if numeric_status and numeric_status >= 200 and numeric_status < 300 then
        self:_debug(string.format('%s %s -> %d', method, url, numeric_status))
        return true, numeric_status, response_text
    end

    self:_log_error('HTTP_RESPONSE', string.format('%s %s returned %s: %s', method, url, status_code or 'nil',
        response_text or ''))
    return false, numeric_status, response_text
end

function Api:_player_context()
    local player_info = windower.ffxi.get_player()
    local server_info = windower.ffxi.get_info()

    if not player_info or not server_info or not server_info.server then
        return nil, 'Cannot determine player/server context'
    end

    local server_id = server_info.server
    local server = resources.servers[server_id]
    local server_name = (server and server.en) or 'Unknown'

    local token_input = string.lower(player_info.name) .. '_' .. tostring(server_id)
    local token = sha.sha256(token_input)

    return {
        player_name = player_info.name,
        server_id = server_id,
        server_name = server_name,
        token = token,
    }
end

function Api:_parse_version(response)
    if not response or response == '' then
        return nil
    end

    local ok, decoded = pcall(json.decode, response)
    if ok and type(decoded) == 'table' and decoded.version then
        local version_string = decoded.version
        if type(version_string) == 'string' and version_string:sub(1, 1) == 'v' then
            version_string = version_string:sub(2)
        end
        return version_string
    end

    local fallback = response:match('"version"%s*:%s*"?v?([^",}%s]+)')
    if fallback then
        return fallback
    end

    return nil
end

function Api:_extract_error_message(response_text, status_code)
    if response_text and response_text ~= '' then
        local ok, decoded = pcall(json.decode, response_text)
        if ok and type(decoded) == 'table' then
            if decoded.message then
                return decoded.message
            end
            if decoded.error then
                return decoded.error
            end
        end
    end

    return string.format('Failed to report (HTTP %s)', status_code or 'unknown')
end

---Check for newer versions of the addon.
---@param current_version string|nil
---@return boolean|nil up_to_date
---@return string|nil message
---@return string|nil latest_version
function Api:check_version(current_version)
    local ok, status_code, response_text = self:_request('GET', self.version_url)
    
    -- Don't log 301 redirects as errors
    if not ok and status_code ~= 301 then
        return nil, 'Unable to check for updates'
    end
    
    if status_code == 301 then
        self:_debug('Received 301 redirect for version check')
        return nil, 'Unable to check for updates'
    end

    local latest = self:_parse_version(response_text)
    if not latest then
        self:_log_error('VERSION_PARSE_ERROR', 'Response: ' .. (response_text or 'nil'))
        return nil, 'Unable to check version'
    end

    if current_version and current_version ~= latest then
        local message = string.format(
            'You are running an outdated version! Current: %s, Latest: %s - Download latest version at: %s/addon',
            current_version, latest, self.base_url)
        return false, message, latest
    end

    return true, nil, latest
end

---Submit a spawn report.
---@param args table
---@return boolean success
---@return number|nil status
---@return string|nil response_text
function Api:submit_spawn_report(args)
    local context, context_error = self:_player_context()
    if not context then
        self:_log_error('SUBMIT_REPORT_CONTEXT', context_error or 'unknown error')
        return false, nil, context_error
    end

    local payload = {
        area = args.area,
        tower = args.tower,
        floor = args.floor,
        server = context.server_name,
        spawnType = args.spawn_type,
        token = context.token,
    }

    if args.mob_name and args.mob_name ~= '' then
        payload.enemyInput = args.mob_name
    end

    local ok, status_code, response_text = self:_request('POST', self.reports_endpoint, payload)

    if ok then
        if not args.silent then
            windower.add_to_chat(123,
                self.formatter.format_spawn_report(args.spawn_type, args.area, args.tower, args.floor, args.mob_name))
        end
        return true, status_code, response_text
    end

    return false, status_code, response_text
end

---Submit a time of death (TOD) report.
---@param args table
---@return boolean success
---@return number|nil status
---@return string|nil response_text
function Api:submit_tod_report(args)
    local context, context_error = self:_player_context()
    if not context then
        self:_log_error('SUBMIT_TOD_CONTEXT', context_error or 'unknown error')
        return false, nil, context_error
    end

    local payload = {
        area = args.area,
        server = context.server_name,
        token = context.token,
    }

    if args.tower and args.floor then
        payload.tower = args.tower
        payload.floor = args.floor
    end

    if args.enemy_input and args.enemy_input ~= '' then
        payload.enemyInput = args.enemy_input
    end

    if args.job_or_name and args.job_or_name ~= '' then
        payload.jobOrName = self.formatter.format_location_name(args.job_or_name)
    end

    local ok, status_code, response_text = self:_request('PUT', self.tod_endpoint, payload)

    if ok then
        if not args.silent then
            windower.add_to_chat(123, self.formatter.format_tod_report(args.area, args.tower, args.floor,
                args.enemy_input, args.job_or_name))
        end
        return true, status_code, response_text
    end

    if status_code == 409 then
        if not args.silent_409 then
            local location = self.formatter.format_location_name(args.area)
            windower.add_to_chat(123, string.format('[WhereIsNM] TOD has already been reported for %s', location))
        end
        return false, status_code, response_text
    end

    if status_code == 422 then
        local location = self.formatter.format_location_name(args.area)
        local subject = args.job_or_name or args.enemy_input or 'unknown'
        windower.add_to_chat(123, string.format('[WhereIsNM] Job/NM: %s not found in %s.', subject, location))
        return false, status_code, response_text
    end

    local error_message = self:_extract_error_message(response_text, status_code)
    local location = self.formatter.format_location_name(args.area)
    windower.add_to_chat(123, string.format('[WhereIsNM] %s for %s', error_message, location))
    return false, status_code, response_text
end

---Submit a reconciliation payload listing all currently observed reports.
---@param args table
---@return boolean success
---@return number|nil status
---@return string|nil response_text
function Api:sync_reports(args)
    local context, context_error = self:_player_context()
    if not context then
        self:_log_error('SYNC_CONTEXT', context_error or 'unknown error')
        return false, nil, context_error
    end

    if not args or not args.area or not args.reports then
        self:_log_error('SYNC_PAYLOAD', 'Missing area or reports')
        return false, nil, 'missing area or reports'
    end

    local payload = {
        server = context.server_name,
        token = context.token,
        area = args.area,
        reports = args.reports,
    }

    if args.observed_count then
        payload.observedCount = args.observed_count
    end

    if args.empty_snapshot ~= nil then
        payload.emptySnapshot = args.empty_snapshot and true or false
    end

    local ok, status_code, response_text = self:_request('POST', self.sync_endpoint, payload)

    if ok and self.debug_enabled() then
        self:_debug(string.format('Sync submitted for %s (%d reports)', args.area, #args.reports))
    end

    if not ok then
        local error_message = self:_extract_error_message(response_text, status_code)
        self:_log_error('SYNC_ERROR', error_message or 'unknown error')
    end

    return ok, status_code, response_text
end

local REPORT_SECTIONS = {
    {key = 'temenos', title = 'TEMENOS'},
    {key = 'apollyon', title = 'APOLLYON'},
}

function Api:_format_reports_display(response_text, server_name)
    local ok, decoded = pcall(json.decode, response_text)
    if not ok or type(decoded) ~= 'table' then
        self:_log_error('REPORT_PARSE_ERROR', 'Response: ' .. (response_text or 'nil'))
        return 'Unable to fetch latest reports'
    end

    local reports_by_area = {}
    local data = decoded.data

    if type(data) == 'table' and type(data.reports) == 'table' then
        reports_by_area = data.reports
    elseif type(data) == 'table' then
        -- data might be an array of entries
        for _, entry in ipairs(data) do
            if type(entry) == 'table' and entry.area then
                reports_by_area[entry.area] = reports_by_area[entry.area] or {}
                table.insert(reports_by_area[entry.area], entry)
            end
        end
    end

    if not next(reports_by_area) then
        return 'No recent data found for ' .. server_name
    end

    local lines = {}
    local header_width = 80
    local title = string.format('[WhereIsNM] Latest Reports for %s', server_name)
    local padding = math.max(0, math.floor((header_width - #title) / 2))
    table.insert(lines, string.rep('-', header_width))
    table.insert(lines, string.rep(' ', padding) .. title)
    table.insert(lines, string.rep('-', header_width))
    table.insert(lines, '')

    local any_entries = false

    for _, section in ipairs(REPORT_SECTIONS) do
        local entries = reports_by_area[section.key]
        if type(entries) == 'table' and #entries > 0 then
            any_entries = true

            local nm_reports = {}
            local question_reports = {}

            local combined = {}
            local order = {}

            for _, entry in ipairs(entries) do
                local enemy_label = entry.enemyDisplay or entry.enemyName or entry.enemyInput or ''
                local key = string.format('%s|%s|%d|%s', entry.area or '', entry.tower or '', entry.floor or 0, enemy_label)

                if not combined[key] then
                    combined[key] = { latest = nil, last_kill = nil }
                    table.insert(order, key)
                end

                local bucket = combined[key]
                local has_tod = (entry.timeOfDeath or entry.time_of_death) and true or false
                local entry_updated = entry.updatedAt or entry.updated_at
                if has_tod then
                    if not bucket.last_kill or (entry_updated and entry_updated > bucket.last_kill.updatedAt) then
                        bucket.last_kill = {
                            entry = entry,
                            minutes = to_number_or_nil(entry.minutesAgo or entry.minutes_ago) or 0,
                        }
                        bucket.last_kill.updatedAt = entry_updated or ''
                    end
                else
                    if not bucket.latest or (entry_updated and entry_updated > bucket.latest.updatedAt) then
                        bucket.latest = {
                            entry = entry,
                            minutes = to_number_or_nil(entry.minutesAgo or entry.minutes_ago) or 0,
                            minutes_since = to_number_or_nil(entry.minutesSinceUpdate or entry.minutes_since_update) or 0,
                            expired = entry.expired == true,
                        }
                        bucket.latest.updatedAt = entry_updated or ''
                    end
                end
            end

            for _, key in ipairs(order) do
                local bucket = combined[key]
                local representative = (bucket.latest and bucket.latest.entry) or (bucket.last_kill and bucket.last_kill.entry)
                if representative then
                    local spawn_type = representative.spawnTypeDisplay or representative.spawnType or ''
                    local enemy_text = representative.enemyDisplay and (' - ' .. representative.enemyDisplay) or ''
                    local display_name = representative.displayName or ''
                    display_name = display_name:gsub('^Temenos %- ', ''):gsub('^Apollyon %- ', ''):gsub(' Tower', '')

                    local time_pairs = {}
                    if bucket.latest then
                        local minutes_ago = bucket.latest.minutes
                        local minutes_since = bucket.latest.minutes_since or minutes_ago
                        if bucket.latest.expired then
                            local reported = self.formatter.format_time_ago(minutes_ago)
                            table.insert(time_pairs, {'Reported', reported})
                            local expired_time = self.formatter.format_time_ago(minutes_since)
                            local expired_label = (spawn_type == 'NM') and 'Killed' or 'No longer active'
                            table.insert(time_pairs, {expired_label, expired_time})
                        else
                            local reported = self.formatter.format_time_ago(minutes_ago)
                            table.insert(time_pairs, {'Reported', reported})
                            if minutes_since ~= minutes_ago then
                                local updated = self.formatter.format_time_ago(minutes_since)
                                table.insert(time_pairs, {'Last seen', updated})
                            end
                        end
                    end
                    if bucket.last_kill then
                        local killed = self.formatter.format_time_ago(bucket.last_kill.minutes)
                        table.insert(time_pairs, {'Killed', killed})
                    end

                    local segments = {}
                    local label_width = 12
                    for _, pair in ipairs(time_pairs) do
                        local label = pair[1] .. ':'
                        table.insert(segments, string.format('%-' .. label_width .. 's %7s ago', label, pair[2]))
                    end

                    local time_str = table.concat(segments, ' | ')
                    local line = string.format('%-28s %s', display_name .. enemy_text, time_str)

                    if spawn_type == 'NM' then
                        table.insert(nm_reports, line)
                    else
                        table.insert(question_reports, line)
                    end
                end
            end

            table.insert(lines, section.title .. '')
            if #nm_reports > 0 then
                table.insert(lines, '\nNM Reports')
                for _, report_line in ipairs(nm_reports) do
                    table.insert(lines, report_line)
                end
            end
            if #question_reports > 0 then
                table.insert(lines, '\n??? Reports')
                for _, report_line in ipairs(question_reports) do
                    table.insert(lines, report_line)
                end
            end
            table.insert(lines, '')
        end
    end

    if not any_entries then
        return 'No recent data found for ' .. server_name
    end
    return table.concat(lines, '\n')
end

---Fetch latest reports for the player's server.
---@param server_id number|nil
---@param limit number|nil
---@return string
function Api:get_latest_reports(server_id, limit)
    local context, context_error = self:_player_context()
    if not context then
        self:_log_error('FETCH_CONTEXT', context_error or 'unknown error')
        return 'Unable to fetch latest reports'
    end

    local resolved_server_id = server_id or context.server_id
    local server = resources.servers[resolved_server_id]
    local server_name = (server and server.en) or context.server_name

    local url = string.format('%s/api/v1/reports/recent/%s?limit=%d&includeExpired=true', self.base_url, server_name, limit or 10)
    local headers = {
        ['Authorization'] = 'Bearer ' .. context.token,
    }

    local ok, _, response_text = self:_request('GET', url, nil, headers)
    if not ok then
        return 'Unable to fetch latest reports'
    end

    return self:_format_reports_display(response_text, server_name)
end


return Api