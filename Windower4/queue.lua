require('luau')
local files = require('files')
local api = require('api')

local M = {}

local queue_file_path = 'data/pending_reports.lua'
local archive_file_path = 'data/archive_reports.lua'
local spawn_queue = {}
local archive = {}

-- Save active queue
local function save_queue()
    local queue_data = files.new(queue_file_path, true)
    local serialized = 'return ' .. T(spawn_queue):tovstring()
    queue_data:write(serialized)
end

-- Save archive
local function save_archive()
    local archive_data = files.new(archive_file_path, true)
    local serialized = 'return ' .. T(archive):tovstring()
    archive_data:write(serialized)
end

-- Load archive once
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

-- Normal NM/??? spawn reports
function M.queue_spawn_report(area, tower, floor, spawn_type, mob_name, mob_id, distance)
    for _, queued_report in ipairs(spawn_queue) do
        if queued_report.area == area and 
           queued_report.tower == tower and 
           queued_report.floor == floor and 
           queued_report.spawn_type == spawn_type then
            if spawn_type == 'question' then return end
            if queued_report.mob_id == mob_id then return end
        end
    end
    
    table.insert(spawn_queue, {
        type = "spawn",
        area = area,
        tower = tower,
        floor = floor,
        spawn_type = spawn_type,
        mob_name = mob_name,
        mob_id = mob_id,
        distance = distance,
        timestamp = os.time()
    })
    
    save_queue()
    local enemy_text = mob_name and (" (" .. mob_name .. ")") or ""
    local spawn_text = spawn_type == "nm" and "NM" or "???"
    windower.add_to_chat(123, string.format('Queued %s: %s %s F%d%s (%.2fy)', 
        spawn_text, area, tower, floor, enemy_text, distance or 0))
end

-- TOD reports
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
    windower.add_to_chat(123, string.format('Queued TOD: %s %s F%s (%s)', 
        area or "?", tower or "?", floor or "?", mob_name or job_or_name or "?"))
end

-- Send queued reports and archive them
function M.send_queued_reports()
    if #spawn_queue == 0 then return end
    
    windower.add_to_chat(123, string.format('Sending %d queued reports...', #spawn_queue))
    
    local sent_count = 0
    for i = #spawn_queue, 1, -1 do
        local report = spawn_queue[i]
        local success = false
        
        if report.type == "spawn" then
            success = api.submit_report(
                report.area, report.tower, report.floor,
                report.spawn_type, report.mob_name, report.mob_id
            )
        elseif report.type == "tod" then
            success = api.submit_tod_report(
                report.area, report.tower, report.floor,
                report.mob_name, report.job_or_name
            )
        end
        
        if success then
            table.insert(archive, report)
            table.remove(spawn_queue, i)
            sent_count = sent_count + 1
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
