local files = require('files')
local settingsFile = require('util.settings')

local M = {}

local spawn_queue_file_path = 'data/queue.lua'
local tod_queue_file_path = 'data/tod_queue.lua'
local objective_queue_file_path = 'data/objective_queue.lua'
local debug_file_path = 'data/debug.txt'

local spawn_queue = {}
local tod_queue = {}
local objective_queue = {}
local api_client

local function current_settings()
    return settingsFile.get()
end

local function debug_enabled()
    local settings = current_settings()
    return settings and settings.debug
end

local function log_queue_debug(message)
    if not debug_enabled() then
        return
    end

    local log_file = files.new(debug_file_path, true)
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    log_file:append(string.format('[%s] QUEUE | %s\n', timestamp, message))
end

local function save_queue_to_file(queue, file_path)
    local queue_file = files.new(file_path, true)
    local serialized_entries = {}

    for i, entry in ipairs(queue) do
        local lines = {'    [' .. i .. ']={'}
        for k, v in pairs(entry) do
            if type(v) == 'string' then
                table.insert(lines, string.format('        ["%s"]=%q,', k, v))
            else
                table.insert(lines, string.format('        ["%s"]=%s,', k, tostring(v)))
            end
        end
        table.insert(lines, '    }')
        table.insert(serialized_entries, table.concat(lines, '\n'))
    end

    queue_file:write("return {\n" .. table.concat(serialized_entries, ",\n") .. "\n}")
end

local function save_spawn_queue()
    save_queue_to_file(spawn_queue, spawn_queue_file_path)
end

local function save_tod_queue()
    save_queue_to_file(tod_queue, tod_queue_file_path)
end

local function save_objective_queue()
    save_queue_to_file(objective_queue, objective_queue_file_path)
end

local function load_queue_from_file(file_path)
    local success, data = pcall(dofile, windower.addon_path .. file_path)
    if success and type(data) == 'table' then
        return data
    end
    return {}
end

function M.load_queue()
    spawn_queue = load_queue_from_file(spawn_queue_file_path)
    tod_queue = load_queue_from_file(tod_queue_file_path)
    objective_queue = load_queue_from_file(objective_queue_file_path)

    if debug_enabled() then
        windower.add_to_chat(123,
            string.format('[Queue] Loaded %d spawn, %d TOD, %d objective reports', #spawn_queue, #tod_queue,
                #objective_queue))
        log_queue_debug(string.format('Loaded queues: %d spawn, %d TOD, %d objective', #spawn_queue, #tod_queue,
            #objective_queue))
    end
end

function M.set_api(api)
    api_client = api
end

function M.queue_spawn_report(area, tower, floor, spawn_type, mob_name)
    for _, entry in ipairs(spawn_queue) do
        if entry.area == area and entry.tower == tower and entry.floor == floor and entry.spawn_type == spawn_type then
            if spawn_type == 'nm' and entry.mob_name == mob_name then
                return
            end
            if spawn_type == 'question' then
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
        timestamp = os.time(),
    })

    log_queue_debug(string.format('SPAWN QUEUED: %s @ %s %s F%d (Total: %d)', mob_name or '???', area, tower, floor,
        #spawn_queue))
    save_spawn_queue()
end

function M.queue_tod_report(area, tower, floor, mob_name, job_or_name)
    for _, entry in ipairs(tod_queue) do
        if entry.area == area and entry.tower == tower and entry.floor == floor and entry.mob_name == mob_name then
            return
        end
    end

    table.insert(tod_queue, {
        type = "tod",
        area = area,
        tower = tower,
        floor = floor,
        mob_name = mob_name,
        job_or_name = job_or_name,
        timestamp = os.time(),
    })

    log_queue_debug(string.format('TOD QUEUED: %s @ %s %s F%d (Total: %d)', mob_name or 'unknown', area, tower or '?',
        floor or 0, #tod_queue))
    save_tod_queue()
end

function M.queue_objective_report(payload)
    if not payload or not payload.area then
        return
    end

    local entry = {
        type = 'objective',
        area = payload.area,
        status = payload.status,
        recorded_at = payload.recorded_at,
        chestsOpened = payload.chestsOpened,
        chestsOpenedMax = payload.chestsOpenedMax,
        nmKilled = payload.nmKilled,
        nmKilledMax = payload.nmKilledMax,
        questionSpawned = payload.questionSpawned,
        questionSpawnedMax = payload.questionSpawnedMax,
        mobKilled = payload.mobKilled,
        mobKilledMax = payload.mobKilledMax,
        timestamp = os.time(),
    }

    table.insert(objective_queue, entry)
    log_queue_debug(string.format('OBJECTIVE QUEUED: %s (Total: %d)', payload.area or 'unknown', #objective_queue))
    save_objective_queue()
    return true
end

local function submit_spawn_reports(opts, announce, errors)
    local spawn_sent = 0
    local spawn_failed = 0
    local limit = opts.spawn_limit

    local index = #spawn_queue
    while index >= 1 do
        local entry = spawn_queue[index]
        local ok, status_code, response_text = api_client:submit_spawn_report({
            area = entry.area,
            tower = entry.tower,
            floor = entry.floor,
            spawn_type = entry.spawn_type,
            mob_name = entry.mob_name,
            silent = not announce,
        })

        if ok then
            table.remove(spawn_queue, index)
            spawn_sent = spawn_sent + 1
        else
            spawn_failed = spawn_failed + 1
            errors[#errors + 1] = {
                type = 'spawn',
                entry = entry,
                status = status_code,
                response = response_text,
            }
        end

        if limit then
            limit = limit - 1
            if limit <= 0 then
                break
            end
        end

        index = index - 1
    end

    if spawn_sent > 0 then
        save_spawn_queue()
    end

    return spawn_sent, spawn_failed
end

local function submit_tod_reports(opts, announce, errors)
    local tod_sent = 0
    local tod_failed = 0
    local limit = opts.tod_limit

    local index = #tod_queue
    while index >= 1 do
        local entry = tod_queue[index]
        local ok, status_code, response_text = api_client:submit_tod_report({
            area = entry.area,
            tower = entry.tower,
            floor = entry.floor,
            enemy_input = entry.mob_name,
            job_or_name = entry.job_or_name,
            silent = not announce,
            silent_409 = not announce,
        })

        if ok then
            table.remove(tod_queue, index)
            tod_sent = tod_sent + 1
        else
            tod_failed = tod_failed + 1
            errors[#errors + 1] = {
                type = 'tod',
                entry = entry,
                status = status_code,
                response = response_text,
            }
        end

        if limit then
            limit = limit - 1
            if limit <= 0 then
                break
            end
        end

        index = index - 1
    end

    if tod_sent > 0 then
        save_tod_queue()
    end

    return tod_sent, tod_failed
end

local function submit_objective_reports(opts, announce, errors)
    opts = opts or {}
    local objective_sent = 0
    local objective_failed = 0

    local limit = opts.objective_limit
    local index = #objective_queue
    while index >= 1 do
        local entry = objective_queue[index]
        local ok, status_code, response_text = api_client:submit_objectives({
            area = entry.area,
            status = entry.status,
            recorded_at = entry.recorded_at,
            chestsOpened = entry.chestsOpened,
            chestsOpenedMax = entry.chestsOpenedMax,
            nmKilled = entry.nmKilled,
            nmKilledMax = entry.nmKilledMax,
            questionSpawned = entry.questionSpawned,
            questionSpawnedMax = entry.questionSpawnedMax,
            mobKilled = entry.mobKilled,
            mobKilledMax = entry.mobKilledMax,
        })

        if ok then
            table.remove(objective_queue, index)
            objective_sent = objective_sent + 1
        else
            objective_failed = objective_failed + 1
            errors[#errors + 1] = {
                type = 'objective',
                entry = entry,
                status = status_code,
                response = response_text,
            }
        end

        if limit then
            limit = limit - 1
            if limit <= 0 then
                break
            end
        end

        index = index - 1
    end

    if objective_sent > 0 then
        save_objective_queue()
    end

    return objective_sent, objective_failed
end

function M.send_queued_reports(opts)
    opts = opts or {}

    if not api_client then
        log_queue_debug('send_queued_reports skipped: API client not configured')
        return {
            spawn_sent = 0,
            spawn_failed = #spawn_queue,
            tod_sent = 0,
            tod_failed = #tod_queue,
            objective_sent = 0,
            objective_failed = #objective_queue,
            errors = {'api_not_configured'},
        }
    end

    local include_spawn = opts.include_spawn ~= false
    local include_tod = opts.include_tod ~= false
    local include_objectives = opts.include_objectives ~= false
    local spawn_limit = opts.spawn_limit
    local tod_limit = opts.tod_limit
    local objective_limit = opts.objective_limit
    local announce = opts.announce == true
    local errors = {}

    local spawn_sent, spawn_failed = 0, 0
    local tod_sent, tod_failed = 0, 0
    local objective_sent, objective_failed = 0, 0

    if include_spawn then
        spawn_sent, spawn_failed = submit_spawn_reports({
            spawn_limit = spawn_limit,
        }, announce, errors)
    end

    if include_tod then
        tod_sent, tod_failed = submit_tod_reports({
            tod_limit = tod_limit,
        }, announce, errors)
    end

    if include_objectives then
        objective_sent, objective_failed = submit_objective_reports({
            objective_limit = objective_limit,
        }, announce, errors)
    end

    log_queue_debug(string.format(
        'Sent queued reports: %d spawn sent, %d spawn failed; %d TOD sent, %d TOD failed; %d objectives sent, %d objectives failed',
        spawn_sent, spawn_failed, tod_sent, tod_failed, objective_sent, objective_failed))

    if announce then
        local total_sent = spawn_sent + tod_sent
        local total_failed = spawn_failed + tod_failed

        if total_sent > 0 then
            windower.add_to_chat(123, string.format('[WhereIsNM] Sent %d queued reports.', total_sent))
        end

        if total_failed > 0 then
            windower.add_to_chat(123,
                string.format('[WhereIsNM] %d queued reports could not be sent; they remain queued.', total_failed))
        end

        if include_objectives then
            if objective_sent > 0 then
                windower.add_to_chat(123, string.format('[WhereIsNM] Sent %d queued objective updates.',
                    objective_sent))
            end
            if objective_failed > 0 then
                windower.add_to_chat(123,
                    string.format('[WhereIsNM] %d objective updates could not be sent; they remain queued.',
                        objective_failed))
            end
        end
    end

    return {
        spawn_sent = spawn_sent,
        spawn_failed = spawn_failed,
        tod_sent = tod_sent,
        tod_failed = tod_failed,
        objective_sent = objective_sent,
        objective_failed = objective_failed,
        errors = errors,
    }
end

function M.get_spawn_queue_count()
    return #spawn_queue
end

function M.get_tod_queue_count()
    return #tod_queue
end

function M.get_objective_queue_count()
    return #objective_queue
end

return M
