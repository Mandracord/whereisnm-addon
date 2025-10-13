require('luau')
local Texts = require('texts')
local Config = require('config')
local Api = require('util.api')

local M = {}
local current_settings
local current_displaybox

local defaults = {}
defaults.text = T {}
defaults.text.bg = {
    alpha = 70,
    visible = true,
}
defaults.text.flags = {
    bold = true,
}
defaults.text.padding = 5
defaults.text.text = {
    font = 'Consolas',
    size = 11,
    stroke = {
        width = 1,
    },
}
defaults.flags = T {}
defaults.flags.bold = true
defaults.flags.draggable = true
defaults.send = true
defaults.submit_on_zone_change = true
defaults.submit_on_floor_change = true
defaults.display_limit = 10
defaults.debug = false
defaults.hud = false
defaults.api_base_url = Api.DEFAULT_BASE_URL
defaults.include_dead = false

---Expose a copy of the defaults table for external use.
---@return table
function M.get_defaults()
    return defaults
end

---Load persisted settings and create the display box.
---@return table settings
---@return table displaybox
function M.load()
    current_settings = Config.load(defaults)
    current_displaybox = Texts.new('${nm_info}', current_settings.text, current_settings)
    return current_settings, current_displaybox
end

---Return the most recently loaded settings table.
---@return table|nil
function M.get()
    return current_settings
end

---Persist settings changes to disk (compatible with the config API variations).
---@param settings table|nil
function M.save(settings)
    local target = settings or current_settings
    if not target then
        return
    end

    local saver = target.save
    if type(saver) == 'function' then
        target:save()
        return
    end

    if config.save then
        config.save(target, defaults)
    end
end

---Return the cached display box instance.
---@return table|nil
function M.get_displaybox()
    return current_displaybox
end

return M
