require("socket")
require("strings") 
require("ltn12")
local https = require("ssl.https")
local json = require("json")
local sha = require("sha2")
res = require('resources')
files = require('files')

local base_url = "https://whereisnm.com"
local reports_endpoint = base_url .. "/api/v1/reports"
local tod_endpoint = base_url .. "/api/v1/reports/tod"

local M = {}

-- Error logging function
local function log_error(error_type, details)
    local log_file = files.new('log.txt', true) 
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local player_info = windower.ffxi.get_player()
    local server_info = windower.ffxi.get_info()
    
    local player_name = player_info and player_info.name or "Unknown"
    local server_name = server_info and res.servers[server_info.server] and res.servers[server_info.server].en or "Unknown"
    
    local log_entry = string.format(
        "[%s] %s | Player: %s | Server: %s | Details: %s\n",
        timestamp, error_type, player_name, server_name, details
    )
    
    log_file:append(log_entry)
end

-- Format location name for display
local function format_location_name(name)
    if not name or name == "" then return name end
    return name:sub(1,1):upper() .. name:sub(2)
end

-- Generate token from player name and server ID
local function generate_token(player_name, server_id)
    local input = string.lower(player_name) .. "_" .. tostring(server_id)
    return sha.sha256(input)
end

-- Submit NM/??? report
function M.submit_report(area, tower, floor, spawn_type, mob_name, mob_id)
    local player_info = windower.ffxi.get_player()
    local server_info = windower.ffxi.get_info()
    
    if not player_info or not server_info then
        log_error("SUBMIT_ERROR", "Cannot get player/server info")
        return false
    end
    
    local player_name = player_info.name
    local server_id = server_info.server
    local server_name = res.servers[server_id].en
    local token = generate_token(player_name, server_id)
    
    local body = string.format(
        '{"area":"%s","tower":"%s","floor":%d,"server":"%s","spawnType":"%s","token":"%s","mobId":%d',
        area, tower, floor, server_name, spawn_type, token, mob_id
    )
    
    if mob_name then
        body = body .. ',"enemyInput":"' .. mob_name .. '"}'
    else
        body = body .. '}'
    end
    
    local success = post_request(reports_endpoint, body)
    
    if success then
        local formatted_area = format_location_name(area)
        local formatted_tower = format_location_name(tower)
        local enemy_text = mob_name and (" (" .. mob_name .. ")") or ""
        local spawn_text = spawn_type == "nm" and "NM" or "???"
        windower.add_to_chat(123, string.format('%s reported: %s, %s F%d%s', spawn_text, formatted_area, formatted_tower, floor, enemy_text))
        return true
    else
        return false
    end
end

-- Submit TOD report (handles both automatic and manual)
function M.submit_tod_report(area, tower, floor, enemy_input, job_or_name)
    local player_info = windower.ffxi.get_player()
    local server_info = windower.ffxi.get_info()
    
    if not player_info or not server_info then
        log_error("TOD_ERROR", "Cannot get player/server info")
        return false
    end
    
    local player_name = player_info.name
    local server_id = server_info.server
    local server_name = res.servers[server_id].en
    local token = generate_token(player_name, server_id)
    
    local body = string.format(
        '{"area":"%s","server":"%s","token":"%s"',
        area, server_name, token
    )
    
    -- Add tower and floor if provided (automatic TOD)
    if tower and floor then
        body = body .. string.format(',"tower":"%s","floor":%d', tower, floor)
    end
    
    if enemy_input then
        body = body .. ',"enemyInput":"' .. enemy_input .. '"'
    end
    
    -- Add job/name if provided (manual TOD)
    if job_or_name then
        body = body .. ',"jobOrName":"' .. job_or_name .. '"'
    end
    
    body = body .. '}'
    
    local success = put_request(tod_endpoint, body)
    
    if success then
        local formatted_area = format_location_name(area)
        
        -- Format output based on available data
        if tower and floor then
            local formatted_tower = format_location_name(tower)
            local enemy_text = enemy_input and (" (" .. enemy_input .. ")") or ""
            windower.add_to_chat(123, string.format('TOD reported: %s, %s F%d%s', formatted_area, formatted_tower, floor, enemy_text))
        elseif job_or_name then
            windower.add_to_chat(123, string.format('TOD reported: %s (%s)', formatted_area, job_or_name))
        else
            windower.add_to_chat(123, string.format('TOD reported: %s', formatted_area))
        end
        return true
    else
        if job_or_name then
            windower.add_to_chat(123, string.format('[WhereIsNM] Failed to report TOD for %s', job_or_name))
        end
        return false
    end
end

function M.get_latest_reports(server_id)
    local player_info = windower.ffxi.get_player()
    local server_info = windower.ffxi.get_info()

    if not player_info or not server_info then
        log_error("FETCH_ERROR", "Cannot get player/server info")
        return "Unable to fetch latest reports"
    end

    local server_name = res.servers[server_info.server].en
    local url = base_url .. "/api/v1/reports/recent/" .. server_name
    local token = generate_token(player_info.name, server_info.server)

    local headers = {
        ["Authorization"] = "Bearer " .. token
    }

    local success, response = get_request(url, headers)

    if success then
        return format_reports_display(response, server_name)
    else
        return "Unable to fetch latest reports"
    end
end

function format_reports_display(reports, server_name)
    local output = "\n"
    local nm_reports = {}
    local question_reports = {}

    local reports_array = reports:match('"reports":%{"temenos":%[(.-)%]%}')
    if not reports_array then
        return "Could not parse reports"
    end

    local report_strings = {}
    for report in reports_array:gmatch('{[^}]*}') do
        table.insert(report_strings, report)
    end

    for _, report_str in ipairs(report_strings) do
        local displayName = report_str:match('"displayName":"([^"]*)"')
        local minutes_ago = report_str:match('"minutes_ago":"([^"]*)"')
        local spawnType = report_str:match('"spawnTypeDisplay":"([^"]*)"')
        local enemyDisplay = report_str:match('"enemyDisplay":"([^"]*)"')
        local time_of_death = report_str:match('"time_of_death":"([^"]*)"')
        
        if displayName and minutes_ago and spawnType then
            local time_text = format_time_ago(tonumber(minutes_ago))
            local enemy_text = enemyDisplay and (" - " .. enemyDisplay) or ""
            
            if time_of_death then
                time_text = "Killed " .. time_text
            end

            local report_line = string.format("%s%s - %s ago\n",
                displayName, enemy_text, time_text)

            if spawnType == "NM" then
                table.insert(nm_reports, report_line)
            else
                table.insert(question_reports, report_line)
            end
        end
    end

    if #nm_reports > 0 then
        output = output .. "Reported NM(s) for " .. server_name .. ":\n"
        for _, report in ipairs(nm_reports) do
            output = output .. report
        end
    end

    if #question_reports > 0 then
        output = output .. "Reported ??? for " .. server_name .. ":\n"
        for _, report in ipairs(question_reports) do
            output = output .. report
        end
    end

    return output
end

function format_time_ago(minutes)
    if minutes < 60 then
        return string.format("%dm", math.floor(minutes))
    else
        local hours = math.floor(minutes / 60)
        local mins = math.floor(minutes % 60)
        return string.format("%dh %dm", hours, mins)
    end
end

-- HTTP POST helper
function post_request(url, body)
    local response_body = {}
    
    local headers = {
        ["User-Agent"] = "WhereIsNM/" .. _addon.version,
        ["Content-Type"] = "application/json",
        ["Content-Length"] = tostring(#body),
        ["X-Client-Type"] = "WhereIsNM-Addon"
    }
    
    local result, status_code = https.request{
        url = url,
        method = "POST", 
        headers = headers,
        source = ltn12.source.string(body),
        sink = ltn12.sink.table(response_body)
    }
    
    local response_text = table.concat(response_body)
    
    if status_code == 200 or status_code == 201 then
        return true
    else
        local error_details = "HTTP " .. (status_code or "unknown") .. ": " .. (response_text or "no response")
        log_error("HTTP_POST_ERROR", string.format("POST to %s failed - %s", url, error_details))
        return false
    end
end

-- HTTP PUT helper for TOD reports
function put_request(url, body)
    local response_body = {}
    
    local headers = {
        ["User-Agent"] = "WhereIsNM/" .. _addon.version,
        ["Content-Type"] = "application/json",
        ["Content-Length"] = tostring(#body),
        ["X-Client-Type"] = "WhereIsNM-Addon"
    }
    
    local result, status_code = https.request{
        url = url,
        method = "PUT", 
        headers = headers,
        source = ltn12.source.string(body),
        sink = ltn12.sink.table(response_body)
    }
    
    local response_text = table.concat(response_body)
    
    if status_code == 200 or status_code == 201 then
        return true
    else
        local error_details = "HTTP " .. (status_code or "unknown") .. ": " .. (response_text or "no response")
        log_error("HTTP_PUT_ERROR", string.format("PUT to %s failed - %s", url, error_details))
        return false
    end
end

-- HTTP GET helper
function get_request(url, headers)
    local response_body = {}

    headers = headers or {}
    headers["User-Agent"] = "WhereIsNM/" .. _addon.version
    headers["X-Client-Type"] = "WhereIsNM-Addon"

    local result, status_code = https.request{
        url = url,
        method = "GET",
        headers = headers,
        sink = ltn12.sink.table(response_body)
    }

    local response_text = table.concat(response_body)

    if status_code == 200 then
        return true, response_text
    else
        local error_details = "HTTP " .. (status_code or "unknown") .. ": " .. (response_text or "no response")
        log_error("HTTP_GET_ERROR", string.format("GET to %s failed - %s", url, error_details))
        return false
    end
end

return M