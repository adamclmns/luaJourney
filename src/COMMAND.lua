-- [[ Adam Clemons | 2024-08 | COMMAND.lua spawns groups, and tells them where to go.
-- Depends on MUD.lua

COMMAND = {}

function COMMAND.initGroups()
	COMMAND.redGroups = coalition.getGroups(coalition.side.RED, nil)
	COMMAND.blueGroups = coalition.getGroups(coalition.side.BLUE, nil)
	env.info("RedGroups = ".. MUD.oneLineSerialize(COMMAND.redGroups))
	env.info("BlueGroups = ".. MUD.oneLineSerialize(COMMAND.blueGroups))
end

-- Function to spawn a ground unit inside a trigger zone
function COMMAND.spawnUnitInTriggerZone(unitType, triggerZoneName, unitName, unitCountry, unitCoalition)

	-- Define the spawn position
	local spawnPoint = MUD.randomPointInZone(triggerZoneName)
	if spawnPoint ~= nil then
		-- Define the unit
		local unit = {
			["type"] = unitType,
			["transportable"] = { ["randomTransportable"] = false }, -- transportable data if needed
			["x"] = spawnPoint.x,
			["y"] = spawnPoint.z,
			["name"] = unitName,
			["heading"] = 0,  -- Direction the unit is facing
			["skill"] = "Average",  -- Skill level of the unit
		}

		-- Define the group
		local group = {
			["visible"] = false,
			["taskSelected"] = true,
			["route"] = {
				["points"] = {
					[1] = {
						["x"] = spawnPoint.x,
						["y"] = spawnPoint.z,
						["type"] = "",
						["action"] = "",
						["alt_type"] = "BARO",
						["formation_template"] = "",
						["speed"] = 0,
						["task"] = {
							["id"] = "ComboTask",
							["params"] = {
								["tasks"] = {},
							},
						},
					},
				},
			},
			["groupId"] = 1,  -- Unique ID for the group (should be unique in the mission)
			["hidden"] = false,
			["units"] = {unit},
			["y"] = spawnPoint.z,
			["x"] = spawnPoint.x,
			["name"] = unitName .. "_group",
			["start_time"] = 0,
			["task"] = "Ground Nothing", -- Default task
		}
		env.info("about to spawn units...")
		-- Add the group to the coalition using the coalition.addGroup function https://wiki.hoggitworld.com/view/DCS_func_addGroup
		coalition.addGroup(unitCountry, Group.Category.GROUND, group)
	else
		env.info("spawnPoint is nil. Unable to place units.")
	end
end

do
	COMMAND.initGroups()

end