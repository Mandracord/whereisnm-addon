local packets = require('packets')

local CaptureConditions = {}
CaptureConditions.__index = CaptureConditions

local OPENING_PATTERN = '(%w+)%s+operator:%s*(.-)%s+(%w+)%s+status:?'
local CONDITION_LABELS = {
    [1] = 'total chests opened',
    [2] = 'roaming nms killed',
    [3] = '??? spawned',
    [4] = 'mob killed',
}

local CONDITION_FIELDS = {
    [1] = 'chestsOpened',
    [2] = 'nmKilled',
    [3] = 'questionSpawned',
    [4] = 'mobKilled',
}

local AREA_BY_ZONE_ID = {
    [37] = 'temenos',
    [38] = 'apollyon',
}

local function clean_message(text)
    if not text then
        return ''
    end

    local cleaned = text:gsub('\30.', ''):gsub('\31.', '')
    cleaned = cleaned:gsub('[%z\1-\8\11\12\14-\31\127]', '')
    return cleaned:lower()
end

local function iso_timestamp(now_fn)
    local timestamp = now_fn and now_fn() or os.time()
    return os.date('!%Y-%m-%dT%H:%M:%SZ', timestamp)
end

function CaptureConditions.new(opts)
    opts = opts or {}
    local instance = {
        logger = opts.logger,
        api = opts.api,
        enabled_provider = opts.enabled_provider or function()
            return false
        end,
        area_context_provider = opts.area_context_provider,
        now_provider = opts.now_provider or os.time,
    }

    return setmetatable(instance, CaptureConditions)
end

function CaptureConditions:_enabled()
    local provider = self.enabled_provider
    if provider then
        local ok, result = pcall(provider)
        if ok and result then
            return true
        end
        return false
    end

    return false
end

function CaptureConditions:_log(message)
    if not self.logger or not message then
        return
    end
    self.logger:log(string.format('[Capture] %s', message))
end

function CaptureConditions:_resolve_area(zone_from_message)
    if self.area_context_provider then
        local ok, context = pcall(self.area_context_provider)
        if ok and context then
            if type(context) == 'table' and context.area then
                return context.area
            end
            if type(context) == 'string' and context ~= '' then
                return context
            end
        end
    end

    local info = windower.ffxi.get_info()
    local zone_id = info and info.zone
    if zone_id and AREA_BY_ZONE_ID[zone_id] then
        return AREA_BY_ZONE_ID[zone_id]
    end

    if zone_from_message and zone_from_message ~= '' then
        local normalized = zone_from_message:lower()
        if normalized == 'temenos' or normalized == 'apollyon' then
            return normalized
        end
    end

    return nil
end

function CaptureConditions:_handle_message_line(line, result)
    local trimmed = (line:match('^%s*(.-)%s*$') or line)
    if trimmed == '' then
        return false
    end

    local operator, zone, status = trimmed:match(OPENING_PATTERN)
    if status then
        result.operator = operator
        if zone then
            zone = zone:match('^%s*(.-)%s*$') or zone
            result.zone = zone:lower()
        end
        result.status = status
        return true
    end

    local idx = trimmed:match('condition%s*(%d+)')
    if not idx then
        return false
    end

    idx = tonumber(idx)
    if not idx then
        return false
    end

    local state
    if trimmed:find('incomplete', 1, true) then
        state = 'incomplete'
    elseif trimmed:find('complete', 1, true) then
        state = 'complete'
    end

    local cur, max = trimmed:match('(%d+)%s*/%s*(%d+)')
    local condition = result.conditions[idx] or {}
    condition.state = state or condition.state
    condition.current = tonumber(cur) or condition.current
    condition.max = tonumber(max) or condition.max
    condition.label = condition.label or CONDITION_LABELS[idx] or string.format('condition %d', idx)
    result.conditions[idx] = condition

    return true
end

function CaptureConditions:_parse_message(source, raw_text)
    if not raw_text or raw_text == '' then
        return nil
    end

    local message = clean_message(raw_text)
    if message == '' then
        return nil
    end

    local result = {
        source = source,
        conditions = {},
    }
    local matched = false

    for line in message:gmatch('[^\r\n]+') do
        if self:_handle_message_line(line, result) then
            matched = true
        end
    end

    if not matched then
        return nil
    end

    return result
end

function CaptureConditions:_state_complete(state)
    if not state or not state.status then
        return false
    end

    local required = {
        'chestsOpened',
        'chestsOpenedMax',
        'nmKilled',
        'nmKilledMax',
        'questionSpawned',
        'questionSpawnedMax',
        'mobKilled',
        'mobKilledMax',
    }

    for _, key in ipairs(required) do
        if state[key] == nil then
            return false
        end
    end

    return true
end

function CaptureConditions:_build_payload(state)
    if not state then
        return nil
    end

    local area = self:_resolve_area(state.area)
    if not area then
        self:_log('Skipped capture: unable to determine area')
        return nil
    end

    return {
        area = area,
        status = state.status,
        recorded_at = state.recorded_at or iso_timestamp(self.now_provider),
        chestsOpened = state.chestsOpened,
        chestsOpenedMax = state.chestsOpenedMax,
        nmKilled = state.nmKilled,
        nmKilledMax = state.nmKilledMax,
        questionSpawned = state.questionSpawned,
        questionSpawnedMax = state.questionSpawnedMax,
        mobKilled = state.mobKilled,
        mobKilledMax = state.mobKilledMax,
    }
end

function CaptureConditions:_merge_result(result)
    if not result then
        return nil
    end

    if result.status and self.pending_state and self.pending_state.status and not self:_state_complete(self.pending_state) then
        self.pending_state = {}
    end

    self.pending_state = self.pending_state or {}
    local state = self.pending_state

    state.area = self:_resolve_area(result.zone) or state.area
    if result.status then
        state.status = result.status
    end
    state.recorded_at = state.recorded_at or iso_timestamp(self.now_provider)

    for idx, condition in pairs(result.conditions) do
        local field = CONDITION_FIELDS[idx]
        if field then
            if condition.current then
                state[field] = condition.current
            end
            if condition.max then
                state[field .. 'Max'] = condition.max
            end
        end
    end

    if self:_state_complete(state) then
        local payload = self:_build_payload(state)
        if payload then
            self.pending_state = nil
            return payload
        end
    end

    self.pending_state = state
    return nil
end

function CaptureConditions:_log_payload(payload)
    if not payload then
        return
    end

    local ordered_keys = {
        'area',
        'status',
        'recorded_at',
        'chestsOpened',
        'chestsOpenedMax',
        'nmKilled',
        'nmKilledMax',
        'questionSpawned',
        'questionSpawnedMax',
        'mobKilled',
        'mobKilledMax',
    }

    self:_log('Logging capture payload')
    for _, key in ipairs(ordered_keys) do
        local value = payload[key]
        if value ~= nil then
            self:_log(string.format('payload.%s = %s', key, tostring(value)))
        end
    end
end

function CaptureConditions:_submit(payload)
    if not payload or not self.api or not self.api.submit_objectives then
        return
    end

    local ok, status_code = self.api:submit_objectives({
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
    })

    if ok then
        local status_text = payload.status or 'n/a'
        self:_log(string.format('Submitted objectives for %s (status: %s)', payload.area, status_text))
        windower.add_to_chat(123, string.format('[WhereIsNM] Objectives submitted for %s (%s).', payload.area,
            status_text))
    else
        local code = tostring(status_code or 'unknown')
        self:_log(string.format('Objective submission failed for %s (HTTP %s)', payload.area, code))
        windower.add_to_chat(167, string.format('[WhereIsNM] Failed to submit objectives for %s (HTTP %s).', payload.area,
            code))
    end
end

function CaptureConditions:_handle_message(source, raw_text)
    if not self:_enabled() then
        return
    end

    local result = self:_parse_message(source, raw_text)
    if not result then
        return
    end

    if result.status then
        self:_log(string.format('Status: %s', result.status))
    end

    local ordered_indexes = {}
    for idx in pairs(result.conditions) do
        ordered_indexes[#ordered_indexes + 1] = idx
    end
    table.sort(ordered_indexes)

    for _, idx in ipairs(ordered_indexes) do
        local condition = result.conditions[idx]
        local label = condition.label or CONDITION_LABELS[idx] or string.format('condition %d', idx)
        if condition.current and condition.max then
            self:_log(string.format('%s: %s/%s', label, condition.current, condition.max))
        elseif condition.state then
            self:_log(string.format('%s: %s', label, condition.state))
        else
            self:_log(string.format('%s: updated', label))
        end
    end

    local payload = self:_merge_result(result)
    if payload then
        self:_log_payload(payload)
        self:_submit(payload)
    end
end

function CaptureConditions:handle_incoming_chunk(packet_id, data)
    if packet_id ~= 0x017 or not data then
        return
    end

    if not self:_enabled() then
        return
    end

    local parsed = packets.parse('incoming', data)
    if not parsed or not parsed.Message then
        return
    end

    self:_handle_message(parsed['Sender Name'] or 'npc', parsed.Message)
end

function CaptureConditions:handle_incoming_text(original, mode)
    if not original or original == '' then
        return
    end

    self:_handle_message(string.format('mode:%s', tostring(mode or 'unknown')), original)
end

function CaptureConditions:has_pending_state()
    return self.pending_state ~= nil
end

return CaptureConditions
