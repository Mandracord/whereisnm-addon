require('luau')
require('strings')
local api = require('util/api')
local util_data = require('util/data')
local queue = require('util/queue')

local M = {}

M.floor_transition_in_progress = false
M.reported_mobs = {}

function M.identifyTargets(current_floor, auto_send)
    if not current_floor or M.floor_transition_in_progress or not auto_send then return end

    local zone_info = windower.ffxi.get_info()
    local zone_id = zone_info.zone
    if zone_id ~= 37 and zone_id ~= 38 then return end

    local mobs = windower.ffxi.get_mob_array()
    local max_distance = 50

    for _, mob in pairs(mobs) do
        if mob.valid_target then
            local distance = mob.distance and math.floor(mob.distance:sqrt() * 100) / 100 or 0
            if distance > 0 and distance <= max_distance then
                local area, tower, floor = util_data.parse_floor_to_api_format(current_floor, zone_id)
                if area and tower and floor then
                    local mob_key = string.format("%s_%s_%d", area, tower, mob.id)

                    if not M.reported_mobs[mob_key] then
                        local success = false

                        if util_data.limbus_nms[zone_id]:contains(mob.name) then
                            success = api.submit_report(area, tower, floor, 'nm', mob.name)
                            if not success then
                                queue.queue_spawn_report(area, tower, floor, 'nm', mob.name, distance)
                                windower.add_to_chat(123, string.format('[WhereIsNM] Report for NM "%s" failed. Queued.', mob.name))
                            end

                        elseif mob.spawn_type == 2 and mob.name == '???' then
                            success = api.submit_report(area, tower, floor, 'question', nil)
                            if not success then
                                queue.queue_spawn_report(area, tower, floor, 'question', nil, distance)
                                windower.add_to_chat(123, '[WhereIsNM] Report for ??? failed. Queued.')
                            end
                        end

                        if success then
                            M.reported_mobs[mob_key] = true
                        end
                    end
                end
            end
        end
    end
end

return M
