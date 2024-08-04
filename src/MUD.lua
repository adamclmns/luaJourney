--  Adam Clemons | 2024-08 | My Utilities for DCS "MUD"

MUD = {}
--[[
    Listing 20.1 example from Programming in Lua Fourth edition by Roberto Ierusalimschy, Lua.org with a few modifications
    I want this to behave like java.util.Set as much as I need it to. It's un-ordered, fast to check occupancy, easy to iterate on, and compare.
]]--
MUD.Set = {}
-- create a new set with the values of a given list
function MUD.Set.new(l)
    local set = {}
    for _, v in pairs (l) do set[v] = true end
    return set
end
-- Union of two Sets, combining all elements without duplicates
function MUD.Set.union(a,b)
    local res = Set.new{}
    for k in pairs(a) do res[k] = true end
    for k in pairs(b) do res[k] = true end
    return res
end
-- Intersection of a set, eliminating all elements not present in both sets.
function MUD.Set.intersect(a,b)
    local res = Set.new{}
    for k in pairs(a) do res[k] = b[k] end
    return res
end
-- toString()
function MUD.Set.tostring()
    local l = {}
    for e in pairs(set) do l[#l +1] = tostring(e) end
    return "{".. table.concat(l,",").."}"
end
-- Set contains value a
function MUD.Set.contains(self,a)
    return self[a] == true
end

--[[
    A function to log things, and put them in the game chat, and/or messages
]]
function MUD.log(message)
    env.info(message)

end
--[[
    Split String by the separator.
]]--
function MUD.splitString(str, separator)
    local res = {}
    local regex = ("([^%s]+)"):format(separator) -- build regex with separator
    for each in str:gmatch(regex) do
        table.insert(res, each)
    end
    return res
end
--[[
    Returns a list of Zone Names in the mission.
]]--
function MUD.getZoneNameList()
    local res = {}
    -- Access the mission's trigger zones
    if env.mission.triggers and env.mission.triggers.zones then
        for _, zone in ipairs(env.mission.triggers.zones) do
            table.insert(res, zone.name) -- Store each zone name in the res table
        end
    end
    return res
end

--[[
    Returns a list of DCS Internal C Type Zone.

    see
]]--
function MUD.getZoneList()
    local res = {}
    -- Access the mission's trigger zones
    if env.mission.triggers and env.mission.triggers.zones then
        for _, zone in ipairs(env.mission.triggers.zones) do
            table.insert(res, zone) -- Store each zone name in the res table
        end
    end
    return res
end

-- Get a random point in a trigger zone by trigger zone name
function MUD.randomPointInZone(triggerZoneName)
    -- Get the trigger zone
    local triggerZone = trigger.misc.getZone(triggerZoneName)
    if not triggerZone then
        env.info("Trigger zone " .. triggerZoneName .. " not found.")
        return
    end

    -- Generate a random position within the trigger zone
    local zoneCenter = triggerZone.point
    local zoneRadius = triggerZone.radius
    local randomAngle = math.random() * 2 * math.pi
    local randomRadius = math.random() * zoneRadius
    local randX = zoneCenter.x + randomRadius * math.cos(randomAngle)
    local randZ = zoneCenter.z + randomRadius * math.sin(randomAngle)

    -- Define the position
    local res = {x = randX, y = 0, z = randZ}
    return res
end
--- Serializes the give value to a string, unless it's already a string or `nil`.
-- borrowed from mist
-- borrowed from slmod
-- @param variable value to serialize
-- @treturn string variable serialized to string
function MUD.basicSerialize(value)
    if value == nil then
        return "\"\""
    else
        if type(value) == 'number' or
           type(value) == 'boolean' or
           type(value) == 'function' or
           type(value) == 'table' then
            return tostring(value)
        elseif type(value) == 'string' then
            value = string.format('%q', value)
            return value
        end
    end
end
--[[
    Taken from Mist.
]]--
--- Serialize a table to a single line string.
-- serialization of a table all on a single line, no comments, made to replace old get_table_string function
-- borrowed from mist
-- borrowed from slmod
-- @tparam table object table to serialize.
-- @treturn string string containing serialized table
function MUD.oneLineSerialize(object)
    if type(object) == 'table' then --function only works for tables!
        local res = {}
        res[#res + 1] = '{ '
        for ind,val in pairs(object) do -- serialize its fields
            if type(ind) == "number" then
                res[#res + 1] = '['
                res[#res + 1] = tostring(ind)
                res[#res + 1] = '] = '
            else --must be a string
                res[#res + 1] = '['
                res[#res + 1] = MUD.basicSerialize(ind)
                res[#res + 1] = '] = '
            end
            if type(val) == 'number' or type(val) == 'boolean' then
                res[#res + 1] = tostring(val)
                res[#res + 1] = ', '
            elseif type(val) == 'string' then
                res[#res + 1] = MUD.basicSerialize(val)
                res[#res + 1] = ', '
            elseif type(val) == 'nil' then -- won't ever happen, right?
                res[#res + 1] = 'nil, '
            elseif type(val) == 'table' then
                res[#res + 1] = MUD.oneLineSerialize(val)
                res[#res + 1] = ', '	 --I think this is right, I just added it
            else
                env.info('Unable to serialize value type $1 at index $2', MUD.basicSerialize(type(val)), tostring(ind))
            end
        end
        res[#res + 1] = '}'
        return table.concat(res)
    else
        return  MUD.basicSerialize(object)
    end
end
