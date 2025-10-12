local TodTracker = {}
TodTracker.__index = TodTracker

---Create a new TOD tracker.
---@param scanner table
---@param queue table
---@param opts table|nil
---@return table
function TodTracker.new(scanner, queue, opts)
    opts = opts or {}

    local debug_provider = opts.debug_enabled
    local initial_debug = opts.debug

    if initial_debug == nil and type(debug_provider) == 'function' then
        local ok, result = pcall(debug_provider)
        if ok then
            initial_debug = result and true or false
        end
    end

    local instance = {
        scanner = scanner,
        queue = queue,
        logger = opts.logger,
        debug = initial_debug and true or false,
        debug_provider = debug_provider,
        interval = opts.interval or 1.25,
        chat_prefix = opts.chat_prefix or string.format('[%s]', _addon and _addon.name or 'WhereIsNM'),
        chat_color = opts.chat_color or 123,
        tracked = {},
        active = false,
    }

    return setmetatable(instance, TodTracker)
end

---Enable or disable chat/debug output.
---@param enabled boolean
function TodTracker:set_debug(enabled)
    self.debug_provider = nil
    self.debug = enabled and true or false
end

---Inject a logger instance.
---@param logger table
function TodTracker:set_logger(logger)
    self.logger = logger
end

---Check whether debug output should be active.
---@return boolean
function TodTracker:debug_enabled()
    if type(self.debug_provider) == 'function' then
        local ok, result = pcall(self.debug_provider)
        if ok then
            return result and true or false
        end
        self.debug_provider = nil
    end

    return self.debug and true or false
end

local function safe_chat(color, message)
    if not message then
        return
    end
    windower.add_to_chat(color, message)
end

function TodTracker:_chat(message)
    if not self:debug_enabled() or not message then
        return
    end

    safe_chat(self.chat_color, string.format('%s %s', self.chat_prefix, message))
end

function TodTracker:_log(message)
    if self.logger and message then
        self.logger:log(message)
    end
end

function TodTracker:reset()
    self.tracked = {}
end

---Handle zone transitions. Returns true if the new zone is a tracked Limbus zone.
---@param zone_id number
---@return boolean
function TodTracker:on_zone_change(zone_id)
    self:reset()
    self:_log('Cleared tracked_tod')

    if not self.scanner.is_limbus_zone(zone_id) then
        self:_log('Not a Limbus zone')
        return false
    end

    self:_log('Entered Limbus zone')
    self:_chat('Entered Limbus zone')
    return true
end

function TodTracker:start()
    if self.active then
        return
    end

    self.active = true
    self:_loop()
end

function TodTracker:stop()
    self.active = false
end

function TodTracker:_schedule_loop()
    if not self.active then
        return
    end

    coroutine.schedule(function()
        self:_loop()
    end, self.interval)
end

---Register NM for TOD tracking.
---@param nm_data table
function TodTracker:add_nm(nm_data)
    if not nm_data or not nm_data.name or self.tracked[nm_data.name] then
        return
    end

    self.tracked[nm_data.name] = {
        name = nm_data.name,
        area = nm_data.area,
        tower = nm_data.tower,
        floor = nm_data.floor,
        mob_id = nm_data.mob_id,
        last_hpp = nil,
        tod_reported = false,
    }

    self:_log(string.format('FOUND NM: %s @ %s %s F%d (mob_id:%s)', nm_data.name, nm_data.area, nm_data.tower,
        nm_data.floor, nm_data.mob_id or 'nil'))
end

local function acquire_mob_by_name(name)
    local mob = windower.ffxi.get_mob_by_name(name)
    if mob and mob.id then
        return mob
    end
end

function TodTracker:_queue_tod(data, reason)
    self:_log(string.format('TOD DETECTED (%s): %s @ %s %s F%d', reason, data.name, data.area, data.tower, data.floor))

    self.queue.queue_tod_report(data.area, data.tower, data.floor, data.name, nil)

    if self:debug_enabled() then
        safe_chat(self.chat_color, string.format('%s TOD queued for %s', self.chat_prefix, data.name))
    end

    data.tod_reported = true
end

function TodTracker:_loop()
    if not self.active then
        return
    end

    local zone_id = windower.ffxi.get_info().zone

    if not self.scanner.is_limbus_zone(zone_id) then
        self.tracked = {}
        self:_schedule_loop()
        return
    end

    if self:debug_enabled() then
        local count = 0
        for _ in pairs(self.tracked) do
            count = count + 1
        end
        self:_log(string.format('TOD Loop: %d NMs in tracked_tod', count))
    end

    for nm_name, data in pairs(self.tracked) do
        local mob = nil

        if data.mob_id then
            mob = windower.ffxi.get_mob_by_id(data.mob_id)
        end

        if not mob then
            local named_mob = acquire_mob_by_name(nm_name)
            if named_mob then
                data.mob_id = named_mob.id
                mob = named_mob
                self:_log(string.format('Acquired mob_id for %s: %d', nm_name, named_mob.id))
            else
                self:_log(string.format('Still no mob_id for %s (not in range)', nm_name))
            end
        end

        if mob then
            data.last_hpp = mob.hpp or 0
            self:_log(string.format('HP UPDATE: %s = %d%%', nm_name, data.last_hpp))

            if data.last_hpp == 0 and not data.tod_reported then
                self:_queue_tod(data, '0% HP')
            end
        else
            self:_log(string.format('MOB DISAPPEARED: %s (last HP: %s%%)', nm_name, data.last_hpp or 'nil'))

            if data.last_hpp and data.last_hpp <= 1 and not data.tod_reported then
                self:_queue_tod(data, 'disappeared')
            end

            self:_log(string.format('REMOVED FROM TRACKING: %s', nm_name))
            self.tracked[nm_name] = nil
        end
    end

    self:_schedule_loop()
end

return TodTracker
