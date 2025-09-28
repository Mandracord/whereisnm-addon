require('luau')
local files = require('files')
local api = require('util/api')
local formatter = require('util/format')

local M = {}

local queue_file_path = 'data/pending_reports.lua'
local archive_file_path = 'data/archive_reports.lua'
local spawn_queue = {}
local archive = {}

local function save_queue()
    local queue_data = files.new(queue_file_path, true)
    local serialized = 'return ' .. T(spawn_queue):tovstring()
    queue_data:write(serialized)
end

local function save_archive()
    local archive_data = files.new(archive_file_path, true)
    local serialized = 'return ' .. T(archive):tovstring()
    archive_data:write(serialized)
end

local function load_archive()
    local success, loaded_data = pcall(dofile, windower.addon_path .. archive_file_path)
    if success and type(loaded_data) == 'table' then
        archive = loaded_data
    else
        archive = {}
        local f = io.open(windower.addon_path .. archive_file_path, 'w')
        if f then
            f:write('return {}')
            f:close()
        end
    end
end

function M.load_queue()
    local success, loaded_data = pcall(dofile, windower.addon_path .. queue_file_path)
    if success and type(loaded_data) == 'table' then
        spawn_queue = loaded_data
        if #spawn_queue > 0 then
            windower.add_to_chat(123, string.format('Loaded %d pending reports', #spawn_queue))
        end
    else
        spawn_queue = {}
        local f = io.open(windower.addon_path .. queue_file_path, 'w')
        if f then
            f:write('return {}')
            f:close()
        end
    end
    load_archive()
end

-- NM/??? create file for submit
function M.queue_spawn_report(area, tower, floor, spawn_type, mob_name, distance)
    for _, queued_report in ipairs(spawn_queue) do
        if queued_report.area == area and 
           queued_report.tower == tower and 
           queued_report.floor == floor and 
           queued_report.spawn_type == spawn_type then
            if spawn_type == 'question' then return end
            
            if spawn_type == 'nm' and queued_report.mob_name == mob_name then
                return
            end
        end
    end
    
    table.insert(spawn_queue, {
        type = "spawn",
        area = area,
        tower = tower,
        floor = floor,
        spawn_type = spawn_type,
        mob_name = mob_name,
        distance = distance,
        timestamp = os.time()
    })
    
    save_queue()
    local spawn_text = formatter.format_spawn_type(spawn_type)
    local location = formatter.format_floor_display(area, tower, floor)
    local enemy_text = formatter.format_enemy_text(mob_name)
    local distance_text = distance and string.format(" (%.2fy)", distance) or ""
    
    windower.add_to_chat(123, string.format('Queued %s: %s%s%s', 
        spawn_text, location, enemy_text, distance_text))
end

-- TOD create file for submit
function M.queue_tod_report(area, tower, floor, mob_name, job_or_name)
    table.insert(spawn_queue, {
        type = "tod",
        area = area,
        tower = tower,
        floor = floor,
        mob_name = mob_name,
        job_or_name = job_or_name,
        timestamp = os.time()
    })
    save_queue()
    
    if tower and floor then
        local location = formatter.format_floor_display(area, tower, floor)
        local enemy_text = formatter.format_enemy_text(mob_name)
        windower.add_to_chat(123, string.format('Queued TOD: %s%s', location, enemy_text))
    else
        local formatted_area = formatter.format_location_name(area)
        windower.add_to_chat(123, string.format('Queued TOD: %s - %s', formatted_area, job_or_name or "unknown"))
    end
end

-- Function for TOD debug logging
function M.add_debug_log(message)
    local log_entry = {
        type = "tod_debug",
        message = message,
        timestamp = os.time(),
        time_string = os.date('%Y-%m-%d %H:%M:%S')
    }
    
    table.insert(archive, log_entry)
    save_archive()
end

-- Send queued reports
function M.send_queued_reports()
    if #spawn_queue == 0 then return end
    
    windower.add_to_chat(123, string.format('Sending %d queued reports...', #spawn_queue))
    
    local sent_count = 0
    local now = os.time()
    local max_age_seconds = 24 * 60 * 60

    for i = #spawn_queue, 1, -1 do
        local report = spawn_queue[i]
        local success, status_code = false, nil

        if now - report.timestamp > max_age_seconds then
            table.remove(spawn_queue, i)
            local location = formatter.format_floor_display(report.area or "?", report.tower or "?", report.floor or "?")
            windower.add_to_chat(123, string.format('Removed stale report from queue: %s', location))
        else
            if report.type == "spawn" then
                success, status_code = api.submit_report(
                    report.area, report.tower, report.floor,
                    report.spawn_type, report.mob_name
                )
            elseif report.type == "tod" then
                success, status_code = api.submit_tod_report(
                    report.area, report.tower, report.floor,
                    report.mob_name, report.job_or_name
                )
            end

            if success then
                table.insert(archive, report)
                table.remove(spawn_queue, i)
                sent_count = sent_count + 1
            elseif status_code == 429 then
                table.insert(archive, { 
                    type = report.type, 
                    area = report.area, 
                    tower = report.tower, 
                    floor = report.floor, 
                    mob_name = report.mob_name, 
                    job_or_name = report.job_or_name, 
                    timestamp = report.timestamp, 
                    skipped = true 
                })
                table.remove(spawn_queue, i)
                local location = formatter.format_floor_display(report.area or "?", report.tower or "?", report.floor or "?")
                windower.add_to_chat(123, string.format('Skipped report (already exists): %s', location))
            end
        end
    end

    save_queue()
    save_archive()
    
    if sent_count > 0 then
        windower.add_to_chat(123, string.format('Successfully sent %d reports', sent_count))
    end
    
    if #spawn_queue > 0 then
        windower.add_to_chat(123, string.format('%d reports remain in queue (failed to send)', #spawn_queue))
    end
end

function M.get_queue_count()
    return #spawn_queue
end

function M.clear_queue()
    spawn_queue = {}
    save_queue()
end

return M