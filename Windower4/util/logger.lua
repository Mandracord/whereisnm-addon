local files = require('files')

local Logger = {}
Logger.__index = Logger

---Create a new logger instance.
---@param opts table|nil
---@return table
function Logger.new(opts)
    opts = opts or {}

    local instance = {
        enabled = opts.enabled or false,
        file_path = opts.file_path or 'data/debug.txt',
    }

    return setmetatable(instance, Logger)
end

---Toggle logging on or off.
---@param enabled boolean
function Logger:set_enabled(enabled)
    self.enabled = enabled and true or false
end

---Write a message to the debug log, including timestamp and zone.
---@param message string
function Logger:log(message)
    if not self.enabled or not message then
        return
    end

    local log_file = files.new(self.file_path, true)
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local zone_info = windower.ffxi.get_info()
    local zone_id = (zone_info and zone_info.zone) or 0

    log_file:append(string.format('[%s] Zone:%d | %s\n', timestamp, zone_id, message))
end

return Logger
