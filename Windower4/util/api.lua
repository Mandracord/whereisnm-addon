require("socket")
require("strings") 
require("ltn12")
local https = require("ssl.https")
local json = require("json")
local sha = require("util/sha2")
local formatter = require('util/format')
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

function M.check_version(current_version)
    local version_url = base_url .. "/version"
    
    local success, response = get_request(version_url)
    
    if success then
        local latest_version = parse_version_from_response(response)
        
        if latest_version then
            if current_version ~= latest_version then
                return string.format("You are running an outdated version! Current: %s, Latest: %s - Download latest version at: %s", 
                    current_version, latest_version, base_url)
            end
        else
            log_error("VERSION_PARSE_ERROR", "Could not parse version from response: " .. response)
            return "Unable to check version"
        end
    else
        return "Unable to check for updates"
    end
end

function parse_version_from_response(response)
    local version = response:match('"version":"([^"]*)"')
    if version and version:sub(1,1) == "v" then
        version = version:sub(2) 
    end
    return version
end

-- Generate token from player name and server ID
local function generate_token(player_name, server_id)
    local input = string.lower(player_name) .. "_" .. tostring(server_id)
    return sha.sha256(input)
end

-- Submit NM/??? report
function M.submit_report(area, tower, floor, spawn_type, mob_name)
    local player_info = windower.ffxi.get_player()
    local server_info = windower.ffxi.get_info()
    
    if not player_info or not server_info then
        log_error("SUBMIT_ERROR", "Cannot get player/server info")
        return false, nil
    end
    
    local player_name = player_info.name
    local server_id = server_info.server
    local server_name = res.servers[server_id].en
    local token = generate_token(player_name, server_id)
    
    local body = string.format(
        '{"area":"%s","tower":"%s","floor":%d,"server":"%s","spawnType":"%s","token":"%s"',
        area, tower, floor, server_name, spawn_type, token
    )
    
    if mob_name then
        body = body .. ',"enemyInput":"' .. mob_name .. '"}'
    else
        body = body .. '}'
    end
    
    local success, status_code = post_request(reports_endpoint, body)
    
    if success then
        windower.add_to_chat(123, formatter.format_spawn_report(spawn_type, area, tower, floor, mob_name))
        return true, status_code
    else
        return false, status_code
    end
end

-- Submit TOD report
function M.submit_tod_report(area, tower, floor, enemy_input, job_or_name)
    local player_info = windower.ffxi.get_player()
    local server_info = windower.ffxi.get_info()
    
    if not player_info or not server_info then
        log_error("TOD_ERROR", "Cannot get player/server info")
        return false, nil
    end
    
    local player_name = player_info.name
    local server_id = server_info.server
    local server_name = res.servers[server_id].en
    local token = generate_token(player_name, server_id)
    
    if job_or_name then
        job_or_name = formatter.format_location_name(job_or_name)
    end
    
    local body = string.format(
        '{"area":"%s","server":"%s","token":"%s"',
        area, server_name, token
    )
    
    if tower and floor then
        body = body .. string.format(',"tower":"%s","floor":%d', tower, floor)
    end
    
    if enemy_input then
        body = body .. ',"enemyInput":"' .. enemy_input .. '"'
    end
    
    if job_or_name then
        body = body .. ',"jobOrName":"' .. job_or_name .. '"'
    end
    
    body = body .. '}'
    
    local success, response_text, status_code = put_request(tod_endpoint, body)
        
    if success then
        windower.add_to_chat(123, formatter.format_tod_report(area, tower, floor, enemy_input, job_or_name))
        return true, status_code
    elseif status_code == 409 then
        local formatted_area = formatter.format_location_name(area)
        windower.add_to_chat(123, string.format('[WhereIsNM] TOD has already been reported for %s', formatted_area))
        return false, status_code
    elseif status_code == 422 then
        local formatted_area = formatter.format_location_name(area)
        windower.add_to_chat(123, string.format('[WhereIsNM] Job/NM: %s not found in %s.', 
            job_or_name or enemy_input or "unknown", formatted_area))
        return false, status_code
    else
        local error_message = "Failed to report TOD"
        if response_text then
            local success_parse, parsed = pcall(json.decode, response_text)
            if success_parse and parsed.message then
                error_message = parsed.message
            elseif success_parse and parsed.error then
                error_message = parsed.error
            else
                error_message = string.format("Failed to report TOD (HTTP %s)", status_code or "unknown")
            end
        end
        
        local formatted_area = formatter.format_location_name(area)
        windower.add_to_chat(123, string.format('[WhereIsNM] %s for %s', error_message, formatted_area))
        return false, status_code
    end
end

-- Fetch latest reports
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

    local headers = { ["Authorization"] = "Bearer " .. token }

    local success, response = get_request(url, headers)

    if success then
        return format_reports_display(response, server_name)
    else
        return "Unable to fetch latest reports"
    end
end

-- Format reports for display
function format_reports_display(reports, server_name)
    local output = "\n"
    local nm_reports = {}
    local question_reports = {}

    local reports_array = reports:match('"reports":%{"temenos":%[(.-)%]%}')
    if not reports_array then
        return "No recent data found for " .. server_name
    end

    for report_str in reports_array:gmatch('{[^}]*}') do
        local displayName = report_str:match('"displayName":"([^"]*)"')
        local minutes_ago = report_str:match('"minutes_ago":"([^"]*)"')
        local spawnType = report_str:match('"spawnTypeDisplay":"([^"]*)"')
        local enemyDisplay = report_str:match('"enemyDisplay":"([^"]*)"')
        local time_of_death = report_str:match('"time_of_death":"([^"]*)"')
        
        if displayName and minutes_ago and spawnType then
            local time_text = formatter.format_time_ago(tonumber(minutes_ago))
            local enemy_text = enemyDisplay and (" - " .. enemyDisplay) or ""
            
            if time_of_death then
                time_text = "Killed " .. time_text
            end

            local report_line = string.format("%s%s - %s ago\n", displayName, enemy_text, time_text)

            if spawnType == "NM" then
                table.insert(nm_reports, report_line)
            else
                table.insert(question_reports, report_line)
            end
        end
    end

    if #nm_reports > 0 then
        output = output .. "Reported NM(s) for " .. server_name .. ":\n" .. table.concat(nm_reports)
    end
    if #question_reports > 0 then
        output = output .. "Reported ??? for " .. server_name .. ":\n" .. table.concat(question_reports)
    end

    return output
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
        return true, status_code
    else
        local error_details = "HTTP " .. (status_code or "unknown") .. ": " .. (response_text or "no response")
        log_error("HTTP_POST_ERROR", string.format("POST to %s failed - %s", url, error_details))
        return false, status_code
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
        return true, response_text, status_code
    elseif status_code == 409 or status_code == 422 then
        return false, response_text, status_code
    else
        local error_details = "HTTP " .. (status_code or "unknown") .. ": " .. (response_text or "no response")
        log_error("HTTP_PUT_ERROR", string.format("PUT to %s failed - %s", url, error_details))
        return false, response_text, status_code
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
