--[[ Adam Clemons | 2024-08 | DEWIT.lua | Do it, as your emperor commands!
]]--
do
    -- Detect Zones.
    STARTUP.mapZones = STARTUP.loadZones()
    env.info("mapZones = "..MUD.oneLineSerialize(STARTUP.mapZones)) -- log the output
    env.info("Spawning Group...") -- letting us know we made it here
    COMMAND.spawnUnitInTriggerZone("M1A2 Abrams", "ramon_emplacement_northwest", "testUnit", country.id.USA, coalition.side.RED) -- Fails without crashing DCS.
    COMMAND.spawnUnitInTriggerZone("M1A2 Abrams", "ramon_emplacement_hatzarim_1", "testUnit", country.id.USA, coalition.side.RED) -- Succeeds in droping an unassigned tank in the round zone.
    --COMMAND.spawnUnitInTriggerZone("Infantry M4", "ramon_emplacement_hatzarim_1", "testUnit", country.id.USA, coalition.side.RED)
end