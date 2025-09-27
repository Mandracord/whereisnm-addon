require('luau')
local files = require('files')
local api = require('api')

local M = {}

local queue_file_path = windower.addon_path .. 'data/pending_reports.lua'
local spawn_queue = {}

function M.load_queue()
    local queue_data = files.new(queue_file_path)
    if queue_data:exists() then
        local success, loaded_data = pcall(dofile, queue_file_path)
        if success and type(loaded_data) == 'table' then
            spawn_queue = loaded_data
            if #spawn_queue > 0 then
                windower.add_to_chat(123, string.format('Loaded %d pending reports', #spawn_queue))
            end
        else
            spawn_queue = {}
        end
    else
        spawn_queue = {}
    end
end

local function save_queue()
    local queue_data = files.new(queue_file_path)
    local serialized = 'return ' .. T(spawn_queue):tovstring()
    queue_data:write(serialized)
end

function M.queue_spawn_report(area, tower, floor, spawn_type, mob_name, mob_id)
    for _, queued_report in ipairs(spawn_queue) do
        if queued_report.area == area and 
           queued_report.tower == tower and 
           queued_report.floor == floor and 
           queued_report.spawn_type == spawn_type and
           queued_report.mob_id == mob_id then
            return
        end
    end
    
    table.insert(spawn_queue, {
        area = area,
        tower = tower,
        floor = floor,
        spawn_type = spawn_type,
        mob_name = mob_name,
        mob_id = mob_id,
        timestamp = os.time()
    })
    
    save_queue()
    
    local enemy_text = mob_name and (" (" .. mob_name .. ")") or ""
    local spawn_text = spawn_type == "nm" and "NM" or "???"
    windower.add_to_chat(123, string.format('Queued %s: %s %s F%d%s', 
        spawn_text, area, tower, floor, enemy_text))
end

function M.send_queued_reports()
    if #spawn_queue == 0 then return end
    
    windower.add_to_chat(123, string.format('Sending %d queued reports...', #spawn_queue))
    
    local sent_count = 0
    for i = #spawn_queue, 1, -1 do
        local report = spawn_queue[i]
        local success = api.submit_report(
            report.area, report.tower, report.floor, 
            report.spawn_type, report.mob_name, report.mob_id
        )
        
        if success then
            table.remove(spawn_queue, i)
            sent_count = sent_count + 1
        end
    end
    
    save_queue()
    
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