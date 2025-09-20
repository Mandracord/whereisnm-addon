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

-- Generate token from player name and server ID
local function generate_token(player_name, server_id)
    local input = string.lower(player_name) .. "_" .. tostring(server_id)
    return sha.sha256(input)
end

local function format_position(pos)
    if not pos then return nil end
    return tostring(pos):gsub("^%((.+)%)$", "%1")
end

-- Submit NM/??? report
function M.submit_report(area, tower, floor, spawn_type, enemy_input, position)
    local player_info = windower.ffxi.get_player()
    local server_info = windower.ffxi.get_info()
    --local position_info = windower.ffxi.get_position()
    
    if not player_info or not server_info then
        log_error("SUBMIT_ERROR", "Cannot get player/server info")
        return false
    end
    
    local player_name = player_info.name
    local server_id = server_info.server
    local server_name = res.servers[server_id].en
    local token = generate_token(player_name, server_id)
    --local position = format_position(position_info)
    
    local body = string.format(
        '{"area":"%s","tower":"%s","floor":%d,"server":"%s","spawnType":"%s","token":"%s"',
        area, tower, floor, server_name, spawn_type, token
    )
    
    if enemy_input then
        body = body .. ',"enemyInput":"' .. enemy_input .. '"'
    end
    
    if position then
        body = body .. ',"position":"' .. position .. '"}'
    else
        body = body .. '}'
    end
    
    local success = post_request(reports_endpoint, body)
    
    if success then
        return true
    else
        return false
    end
end

-- Submit TOD report
function M.submit_tod_report(area, tower, floor, enemy_input)
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
        '{"area":"%s","tower":"%s","floor":%d,"server":"%s","token":"%s"',
        area, tower, floor, server_name, token
    )
    
    if enemy_input then
        body = body .. ',"enemyInput":"' .. enemy_input .. '"}'
    else
        body = body .. '}'
    end
    
    local success = put_request(tod_endpoint, body)
    
    if success then
        return true
    else
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

function M.check_addon_version()
    local url = 'https://api.github.com/repos/Mandracord/whereisnm-addon/releases/latest'
    local success, response = pcall(function()
        return windower.http_get(url)
    end)
    
    if success and response then
        local data = json.decode(response)
        if data and data.tag_name then
            return data.tag_name:gsub('v', '')
        end
    end
    
    return nil
end

function format_reports_display(reports, server_name)
    local output = "Recent spawns:\n"
    local nm_reports = {}
    local question_reports = {}
    
    for report_block in reports:gmatch('{"id":%d+.-"spawnTypeDisplay":"[^"]+"}') do
        local displayName = report_block:match('"displayName":"([^"]+)"')
        local minutes_ago = report_block:match('"minutes_ago":"([^"]+)"')
        local position = report_block:match('"position":"([^"]+)"')
        local spawnType = report_block:match('"spawnTypeDisplay":"([^"]+)"')
        local enemyDisplay = report_block:match('"enemyDisplay":"([^"]+)"')
        local time_of_death = report_block:match('"time_of_death":"([^"]+)"')
        
        if displayName and minutes_ago and spawnType then
            local time_text = format_time_ago(tonumber(minutes_ago))
            local pos_text = position and (" (" .. position .. ")") or ""
            local enemy_text = enemyDisplay and (" - " .. enemyDisplay) or ""
            local status_text = ""
            
            if time_of_death and time_of_death ~= "null" then
                status_text = " (KILLED)"
                time_text = "Killed " .. time_text
            end
            
            local report_line = string.format("%s%s%s%s - %s ago\n", 
                displayName, enemy_text, status_text, pos_text, time_text)
            
            if spawnType == "NM" then
                table.insert(nm_reports, report_line)
            else
                table.insert(question_reports, report_line)
            end
        end
    end
    
    -- Display NM reports first
    if #nm_reports > 0 then
        output = output .. "Reported NM(s) for " .. server_name .. ":\n"
        for _, report in ipairs(nm_reports) do
            output = output .. report
        end
    end
    
    -- Display ??? reports
    if #question_reports > 0 then
        output = output .. "Reported ??? for " .. server_name .. ":\n"
        for _, report in ipairs(question_reports) do
            output = output .. report
        end
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

function format_time_ago(minutes)
    if minutes < 60 then
        return string.format("%dm", math.floor(minutes))
    else
        local hours = math.floor(minutes / 60)
        local mins = math.floor(minutes % 60)
        return string.format("%dh %dm", hours, mins)
    end
end

return M