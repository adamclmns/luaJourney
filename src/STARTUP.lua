-- Adam Clemons | 2024-08 | Reading zones from the miz, and organizing them based on my ideas for a Dynamic Mission
-- Depends on MUD.lua
-- Depends on COMMAND.lua

STARTUP = {}
STARTUP.mapZones = {}

--[[
    Parse the parameters from a Zone Name into some sane-defaults
]]--
function STARTUP.readZoneParams(name,params)
    -- if there's only one param, this is a region
    if #params == 1 then
        local res = {
            zoneName = name,
            zoneType = "region",
            gdp = 0,
            count_industrial = 0,
            count_population = 0,
            side = coalition.side.NEUTRAL,
            isFocus = false,
        }
        return res
    end
    -- if there's three params, this is industrial, population, or military, or base.
    if #params == 3 then
        local res = {
            zoneName = name,
            zoneType = params[2],
            zoneRegion = params[1],
            zoneActive = true
        }
        return res
    end
    -- if there's 4 params, and the second param is 'emplacement', this is an emplacement.
    if #params == 4 and params[2] == 'emplacement' then
        local res = {
            zoneName = name,
            zoneType = params[2],
            zoneRegion = params[1],
            opposingRegion = params[3],
            pairedZoneName = params[3].."_"..params[2].."_"..params[1].."_"..params[4],
            zoneActive = false, -- are troops here right now?
            troopsPresent = {},
        }
        return res
    end
    if #params == 4 and params[2] == 'strategic' then
        local res = {
            zoneName = name,
            zoneType = params[2],
            uniqueName = params[3],
            zoneActive = true, -- is it blown up?
            targetType = params[4] -- static | dynamic
        }
        return res
    end
    env.info("STARTUP :: Unable to determine zone type for zone ",name)
end

--[[
Get and Loop through the Zones. Build up the table that describes the map, and return it.mapZones
]]--
function STARTUP.loadZones()
    local res = {
        regions = {},
        subZones = {},
        emplacements = {},
        strategics = {}
    }
    for _,zone in ipairs(MUD.getZoneList()) do
        local nm = zone.name
        env.info("Parsing Zone with Name: "..nm)
        local params = MUD.splitString(nm,'_')
        local zInfo = STARTUP.readZoneParams(nm,params)
        if zInfo.zoneType == "region" then
            table.insert(res.regions,zInfo)
        elseif zInfo.zoneType == "emplacement" then
            table.insert(res.emplacements,zInfo)
        elseif zInfo.zoneType == "strategic" then
            table.insert(res.strategics, zInfo)
        else
            if zInfo ~= nil then
                table.insert(res.subZones,zInfo)
            else
                env.info("STARTUP :: Ignoring Zone "..zone.name.." in STARTUP.loadZones()")
            end
        end
    end
    return res
end

