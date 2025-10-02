require('luau')
local files = require('files')
local api = require('util/api')
local formatter = require('util/format')

local M = {}

local queue_file_path = 'data/pending_reports.lua'
local spawn_queue = {}

local function save_queue()
    local queue_data = files.new(queue_file_path, true)
    local serialized = 'return ' .. T(spawn_queue):tovstring()
    queue_data:write(serialized)
end

function M.load_queue()
    local success, loaded_data = pcall(dofile, windower.addon_path .. queue_file_path)
    if success and type(loaded_data) == 'table' then
        spawn_queue = loaded_data
        if #spawn_queue > 0 then
            windower.add_to_chat(123, string.format('[WhereIsNM] Loaded %d pending reports', #spawn_queue))
        end
    else
        spawn_queue = {}
        local f = io.open(windower.addon_path .. queue_file_path, 'w')
        if f then
            f:write('return {}')
            f:close()
        end
    end
end

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
end

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
end

function M.send_queued_reports()
    if #spawn_queue == 0 then return end
    
    windower.add_to_chat(123, string.format('[WhereIsNM] Sending %d queued reports...', #spawn_queue))
    
    local sent_count = 0
    local now = os.time()
    local max_age_seconds = 24 * 60 * 60

    for i = #spawn_queue, 1, -1 do
        local report = spawn_queue[i]
        local success, status_code = false, nil

        if now - report.timestamp > max_age_seconds then
            table.remove(spawn_queue, i)
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
                table.remove(spawn_queue, i)
                sent_count = sent_count + 1
            elseif status_code == 409 or status_code == 429 then
                table.remove(spawn_queue, i)
            end
        end
    end

    save_queue()
    
    if sent_count > 0 then
        windower.add_to_chat(123, string.format('[WhereIsNM] Successfully sent %d reports', sent_count))
    end
    
    if #spawn_queue > 0 then
        windower.add_to_chat(123, string.format('[WhereIsNM] %d reports remain queued', #spawn_queue))
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