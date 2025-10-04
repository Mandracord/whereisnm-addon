require('luau')
local files = require('files')
local api = require('util/api')
local formatter = require('util/format')

local M = {}

local queue_file_path = 'data/pending_reports.lua'
local history_file_path = 'data/history.lua'

local spawn_queue = {}
local report_history = {}

local function save_queue()
    local queue_data = files.new(queue_file_path, true)
    local serialized = 'return ' .. T(spawn_queue):tovstring()
    queue_data:write(serialized)
end

local function save_history()
    local history_data = files.new(history_file_path, true)
    local serialized = 'return ' .. T(report_history):tovstring()
    history_data:write(serialized)
end

local function load_history()
    local success, loaded_data = pcall(dofile, windower.addon_path .. history_file_path)
    if success and type(loaded_data) == 'table' then
        report_history = loaded_data
    else
        report_history = {}
    end
end

local function log_history(report, status, status_code)
    local entry = {
        type = report.type,
        area = report.area,
        tower = report.tower,
        floor = report.floor,
        spawn_type = report.spawn_type,
        mob_name = report.mob_name,
        job_or_name = report.job_or_name,
        distance = report.distance,
        timestamp = report.timestamp,
        readable_time = os.date('%Y-%m-%d %H:%M:%S', report.timestamp),
        result = status,
        status_code = status_code
    }

    table.insert(report_history, entry)

    while #report_history > 50 do
        table.remove(report_history, 1)
    end

    save_history()
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

    load_history()
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
    for _, queued_report in ipairs(spawn_queue) do
        if queued_report.type == "tod" and
           queued_report.area == area then
            if tower and floor and mob_name then
                if queued_report.tower == tower and 
                   queued_report.floor == floor and
                   queued_report.mob_name == mob_name then
                    return 
                end
            end
        end
    end
    
    table.insert(spawn_queue, 1, {
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

    local now = os.time()
    local max_age_seconds = 24 * 60 * 60
    local sent_count = 0
    local duplicate_count = 0
    local failed_count = 0

    local function send_next(i)
        if i < 1 or #spawn_queue == 0 then
            save_queue()
            if sent_count > 0 then
                windower.add_to_chat(123, string.format('[WhereIsNM] Successfully sent %d reports', sent_count))
            end
            if duplicate_count > 0 then
                windower.add_to_chat(123, string.format('[WhereIsNM] %d duplicate reports skipped', duplicate_count))
            end
            if failed_count > 0 then
                windower.add_to_chat(123, string.format('[WhereIsNM] %d reports removed (not found)', failed_count))
            end
            if #spawn_queue > 0 then
                windower.add_to_chat(123, string.format('[WhereIsNM] %d reports remain queued', #spawn_queue))
            end
            return
        end

        local report = spawn_queue[i]

        if now - report.timestamp > max_age_seconds then
            table.remove(spawn_queue, i)
            save_queue()
            send_next(i - 1)
        else
            local success, status_code = false, nil

            if report.type == "spawn" then
                success, status_code = api.submit_report(
                    report.area, report.tower, report.floor,
                    report.spawn_type, report.mob_name
                )
            elseif report.type == "tod" then
                success, status_code = api.submit_tod_report(
                    report.area, report.tower, report.floor,
                    report.mob_name, report.job_or_name, true
                )
            end

            log_history(report, success and "success" or "error", status_code)
            if success or status_code == 409 or status_code == 429 or status_code == 404 then
                table.remove(spawn_queue, i)
                if success then 
                    sent_count = sent_count + 1
                elseif status_code == 409 then 
                    duplicate_count = duplicate_count + 1
                elseif status_code == 404 then
                    failed_count = failed_count + 1
                end
                save_queue()
                coroutine.schedule(function()
                    send_next(i - 1)
                end, 2)
            else
                save_queue()
                coroutine.schedule(function()
                    send_next(i - 1)
                end, 2)
            end
        end
    end

    send_next(#spawn_queue)
end

function M.get_queue_count()
    return #spawn_queue
end

function M.clear_queue()
    spawn_queue = {}
    save_queue()
end

function M.get_history_count()
    return #report_history
end

return M