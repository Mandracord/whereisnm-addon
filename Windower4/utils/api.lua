require("socket")
require("strings") 
require("ltn12")
local https = require("ssl.https")
local json = require("json")
local sha = require("sha2")
res = require('resources')

local base_url = "http://localhost:3000"
local reports_endpoint = base_url .. "/api/v1/reports"

local M = {}

-- Generate token from player name and server ID
local function generate_token(player_name, server_id)
    local input = string.lower(player_name) .. "_" .. tostring(server_id)
    return sha.sha256(input)
end

local function format_position(pos)
    if not pos then return nil end
    return tostring(pos):gsub("^%((.+)%)$", "%1")
end

-- Submit NM/??? report to backend
function M.submit_report(area, tower, floor, spawn_type, position)
    local player_info = windower.ffxi.get_player()
    local server_info = windower.ffxi.get_info()
    local position_info = windower.ffxi.get_position()
    
    if not player_info or not server_info then
        log("Cannot get player/server info")
        return false
    end
    
    local player_name = player_info.name
    local server_id = server_info.server
    local server_name = res.servers[server_id].en
    local token = generate_token(player_name, server_id)
    local position = format_position(position_info)
    
    local body = json.stringify({
        area = area,
        tower = tower, 
        floor = floor,
        server = server_name,
        spawnType = spawn_type,
        token = token,
        position = position
    })
    
    local success, response = post_request(reports_endpoint, body)
    
    if success then
        log("Report submitted successfully: " .. spawn_type .. " at " .. area .. " " .. tower .. " F" .. floor)
        return true
    else
        log("Failed to submit report: " .. (response or "unknown error"))
        return false
    end
end

-- Get latest reports for server
function M.get_latest_reports(server_id)
    local player_info = windower.ffxi.get_player()
    local server_info = windower.ffxi.get_info()

    if not player_info or not server_info then
        log("Cannot get player/server info")
        return "Unable to fetch latest reports"
    end

    local player_name = player_info.name
    local server_id = server_info.server
    local server_name = res.servers[server_id].en
    local token = generate_token(player_name, server_id)

    local url = base_url .. "/api/v1/reports/recent/" .. server_name

    local headers = {
        ["Authorization"] = "Bearer " .. token
    }

    local success, response = get_request(url, headers)

    if success then
        local result = json.parse(response)
        if result and result.success and result.data.reports then
            return format_reports_display(result.data.reports)
        end
    end

    return "Unable to fetch latest reports"
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
        return true, response_text
    else
        return false, "HTTP " .. status_code .. ": " .. response_text
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
        return false, "HTTP " .. status_code .. ": " .. response_text
    end
end



-- Format reports for display
function format_reports_display(reports)
    local output = "Recent spawns:\n"
    
    for area, area_reports in pairs(reports) do
        output = output .. string.upper(area) .. ":\n"
        for _, report in ipairs(area_reports) do
            local time_text = format_time_ago(tonumber(report.minutes_ago))
            local pos_text = report.position and (" (" .. report.position .. ")") or ""
            output = output .. string.format("  %s - %s ago%s\n", 
                report.displayName, time_text, pos_text)
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

return M