# The beginning of an adventure...

I've been dabbling with Lua on and off in different contexts for 2 years as I start this project. I'm bound to get a lot
wrong, and I hope to document that, and how I find the right way in this journal page. I've been thinking about making 
my own dynamic campaign for some time, but haven't felt the time was right until now. 

Hopefully it doesn't take me another year to get started on this. This is probably going to take several months before 
I show it to anyone.

I've decided that the best way for me to organize this is by the type of functions I'm implementing. This is going to 
result in some things being jumbled up time-wise, but I think it'll make more sense in the end. The details will be 
presented as smaller problems that I need to solve in service of the ultimate goal, building a dynamic campaign. I'll 
share my influences, and where I copied the code, where appropriate.  

## Problem Statement:

I want to create dynamic, persistent, PvE mission in DCS for multiplayer servers. I want to try a new take on Zone-Based
capture.

Key Design Features:

* Region-based Zones
  * There will be Regions, with a variety of sub-zone types (Military, Population, Industrial, Emplacement) that will 
    help make each Region distinct, and strategically valuable.
  * The battle will only be focused on a single region at a time. Making it clear where the fight is, and focusing 
    server resources.
* Economy
  * A supply system based around "GDP" will be used to purchase units, structures, and re-supply of warehouses. 
  * A simulated supply network will move items between warehouses in different regions.
* Easily reproduced and modified.
  * Should be easy to reproduce and maintain and remix, for a variety of scenarios. 
* No dependencies... We'll see how far I can get before revisiting that.


### Create a naming convention for ME Trigger Zones that I can use to build a lua-model of the battlefield without having to transcribe zone names into lua.

The format will use `_` to split the trigger zone label into parts to be parsed individually to further identify and 
configure that zone. Zone names will just be a collection of identifiers stitched together with underscores. 

I want to have different types of zones constrained by a large zone, so the sub-zones can provide extra behavior, or 
value to a zone.

- Region Zones, one word. 

    `[region]`
    
    - Regions will cover most of the Mission map. A region will change coalition ownership when all emplacements have 
      been defeated, and troops have been sent to each subZone to take control. 
    - TODO: More thoughts on the 'resisting' and 'subduing' statuses for regions and their effects on production.
  
- SubZone - `population`, `military`, or `industrial`, etc., 3 words.
    
    `[region]_[type]_[index]`
    
    - The presence of these will determine the mix of population/military/industrial points a region has, which will 
      impact the speed at which GDP is accrued by a coalition, and the speed with which units can be dispatched. 
  
- Emplacement Zone, 4 words. predictable second part.

    `[region]_emplacement_[opposingRegion]_[index]`

    - Emplacement zones are meant to come in pairs. An emplacement will always have an opposing emplacement in the 
      neighboring region. Sometimes a region might have multiple emplacement zones. When multiple emplacement pairs are 
      shared between two Regions, the index will be used to identify the pairs.     
    - The `opposingRegion` and `index` for two opposing emplacements ensure the zones can be matched up to create 
      conflict zones on the map. For example, `region1_emplacement_region2_1`, and `region2_emplacement_region1_1` are a 
      matched pair of emplacements.
  
- Strategic Target Zone, 4 words. Predictable second part.

    `[region]_strategic_[uniquename]_[static|dynamic]`

    - If the zone is designated as `static` then the on-map static objects will be referenced for the strategic target. 
      On reloading of a prior save, if destroyed in a previous session, the static objects will be removed in the zone. 
    
    - If the zone is designated as `dynamic` then the on-map static objects in the area will be removed and replaced 
      with a neutral factory, workshop, or communications equipment. The selection made will be saved to the mission 
      persistence system, but the same selection may not be made when restarting the mission.
    - For intended results, a size between `1500` and `3000` should be optimal

### Implement some Lua that can parse Zones using the defined naming convention, and build a Lua Table that resembles a Mission State.

To build a dynamic scenario out of a bunch of Zone names, we first have to get all the Zone names. Because this seems 
like something I'll be doing often, I started a utility called `MUD.lua`. In `MUD` I can implement things that might be
useful elsewhere, and re-use the code more easily. 

Getting all the zones from the `env.mission` object was way easier than I expected.
```lua
    --[[
        Enumerate all Zones in the Mission
    ]]--
    function MUD.getZoneList()
        local res = {}
        -- Access the mission's trigger zones
        if env.mission.triggers and env.mission.triggers.zones then
            for _, zone in ipairs(env.mission.triggers.zones) do
                table.insert(res, zone) -- Store each zone in the res table
            end
        end

        return res
    end
```

Once I had the names, I needed to split those names by underscores. Lua `string` doesn't have `split()`, it has 
`gmatch()` instead. So I implemented a regex, that is so simple, there's 4 nearly identical implementations on 
StackOverflow for this.
```lua
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
```

To parse those names, I built out the top level data-structure as a table, and then stubbed an empty function 
`readZoneParams` to figure out later. I knew that the only really 'special' type of zones I had so far were 'region', 
'emplacement' and 'strategic', and that everything else was going to follow similar 'sub-zone' rules. Using this 
knowledge, I made the assumption that zones that aren't the other types are all sub-zones.

```lua
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
            table.insert(res.subZones,zInfo)
        end
    end
    return res
end
```

Some time later, I realized `readZoneParams` function wasn't too hard. I knew I needed to put a `zoneType` parameter in 
each type, and I filled out some fields to support passing ideas with absolutely no idea how to implement them.

```lua 
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
```

After all of that, I transcribed some of the serialization functions from Mist so I could generate the following output 
of the table created by `loadZones`. Looking at the output, I feel like there's still some things missing, and I could 
probably refine this even more by parsing back through it once I have all the zones sorted. 

This will just be a startup task, and I'll need to measure its performance later on to do some optimization. Since I 
already know I'm coming back to this part of the code, I'm not too worried about inefficiency. I really just want to 
get some moving parts built out so I can start proofing out more functions. 


```lua
mapZones = {
    ["regions"] = {
        [1] = {
            ["zoneType"] = "region",
            ["isFocus"] = false,
            ["gdp"] = 0,
            ["zoneName"] = "ramon",
            ["side"] = 0,
            ["count_industrial"] = 0,
            ["count_population"] = 0
        },
        [2] = {
            ["zoneType"] = "region",
            ["isFocus"] = false,
            ["gdp"] = 0,
            ["zoneName"] = "hatzerim",
            ["side"] = 0,
            ["count_industrial"] = 0,
            ["count_population"] = 0
        },
        [3] = {
            ["zoneType"] = "region",
            ["isFocus"] = false,
            ["gdp"] = 0,
            ["zoneName"] = "elarish",
            ["side"] = 0,
            ["count_industrial"] = 0,
            ["count_population"] = 0
        },
        [4] = {
            ["zoneType"] = "region",
            ["isFocus"] = false,
            ["gdp"] = 0,
            ["zoneName"] = "melez",
            ["side"] = 0,
            ["count_industrial"] = 0,
            ["count_population"] = 0
        }
    },
    ["strategics"] = {
        [1] = {
            ["zoneType"] = "strategic",
            ["zoneName"] = "hatzerim_strategic_watertreatment_static",
            ["targetType"] = "static",
            ["zoneActive"] = true,
            ["uniqueName"] = "watertreatment"
        },
        [2] = {
            ["zoneType"] = "strategic",
            ["zoneName"] = "hatzerim_strategic_factory_dynamic",
            ["targetType"] = "dynamic",
            ["zoneActive"] = true,
            ["uniqueName"] = "factory"
        }
    },
    ["subZones"] = {
        [1] = {
            ["zoneName"] = "melez_base_1",
            ["zoneActive"] = true,
            ["zoneRegion"] = "melez",
            ["zoneType"] = "base"
        },
        [2] = {
            ["zoneName"] = "melez_industrial_1",
            ["zoneActive"] = true,
            ["zoneRegion"] = "melez",
            ["zoneType"] = "industrial"
        },
        [3] = {
            ["zoneName"] = "melez_population_1",
            ["zoneActive"] = true,
            ["zoneRegion"] = "melez",
            ["zoneType"] = "population"
        },
        [4] = {
            ["zoneName"] = "elarish_population_1",
            ["zoneActive"] = true,
            ["zoneRegion"] = "elarish",
            ["zoneType"] = "population"
        },
        [5] = {
            ["zoneName"] = "elarish_industrial_1",
            ["zoneActive"] = true,
            ["zoneRegion"] = "elarish",
            ["zoneType"] = "industrial"
        },
        [6] = {
            ["zoneName"] = "elarish_base_1",
            ["zoneActive"] = true,
            ["zoneRegion"] = "elarish",
            ["zoneType"] = "base"
        },
        [7] = {
            ["zoneName"] = "ramon_base_1",
            ["zoneActive"] = true,
            ["zoneRegion"] = "ramon",
            ["zoneType"] = "base"
        },
        [8] = {
            ["zoneName"] = "ramon_population_1",
            ["zoneActive"] = true,
            ["zoneRegion"] = "ramon",
            ["zoneType"] = "population"
        },
        [9] = {
            ["zoneName"] = "hatzerim_population_1",
            ["zoneActive"] = true,
            ["zoneRegion"] = "hatzerim",
            ["zoneType"] = "population"
        },
        [10] = {
            ["zoneName"] = "hatzerim_industrial_1",
            ["zoneActive"] = true,
            ["zoneRegion"] = "hatzerim",
            ["zoneType"] = "industrial"
        },
        [11] = {
            ["zoneName"] = "hatzerim_base_1",
            ["zoneActive"] = true,
            ["zoneRegion"] = "hatzerim",
            ["zoneType"] = "base"
        }
    },
    ["emplacements"] = {
        [1] = {
            ["zoneType"] = "emplacement",
            ["zoneRegion"] = "ramon",
            ["opposingRegion"] = "hatzarim",
            ["zoneName"] = "ramon_emplacement_hatzarim_1",
            ["troopsPresent"] = {},
            ["zoneActive"] = false,
            ["pairedZoneName"] = "hatzarim_emplacement_ramon_1"
        },
        [2] = {
            ["zoneType"] = "emplacement",
            ["zoneRegion"] = "hatzerim",
            ["opposingRegion"] = "ramon",
            ["zoneName"] = "hatzerim_emplacement_ramon_1",
            ["troopsPresent"] = {},
            ["zoneActive"] = false,
            ["pairedZoneName"] = "ramon_emplacement_hatzerim_1"
        },
        [3] = {
            ["zoneType"] = "emplacement",
            ["zoneRegion"] = "hatzerim",
            ["opposingRegion"] = "elarish",
            ["zoneName"] = "hatzerim_emplacement_elarish_1",
            ["troopsPresent"] = {},
            ["zoneActive"] = false,
            ["pairedZoneName"] = "elarish_emplacement_hatzerim_1"
        },
        [4] = {
            ["zoneType"] = "emplacement",
            ["zoneRegion"] = "elarish",
            ["opposingRegion"] = "hatzerim",
            ["zoneName"] = "elarish_emplacement_hatzerim_1",
            ["troopsPresent"] = {},
            ["zoneActive"] = false,
            ["pairedZoneName"] = "hatzerim_emplacement_elarish_1"
        }
    }
}

```

### Creating AI Units Programmatically. 

Zones are great, but I gotta put things in the zones, and those things need to go to other zones and do things. Building
the unit group data feels intimidating. So, instead I'm going to start with the simples case of making a single Ground 
Unit.  

First, I wanted to pick a random point in a named Trigger Zone, so things aren't always dead-center. I might make 
variations of this function later for different uses.

This function only works on circular zones, because I'm using a radius and some trig to find the point in the zone.
```lua
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
```

The next part was a lot of trial and error. I found [this](https://www.digitalcombatsimulator.com/en/support/faq/1257/#3307662) function.

`Group function coalition.addGroup(enum country.id country, enum Group.Category groupCategory, table groupData)` 

With a bit more information from the [MOOSE Docs](https://wiki.hoggitworld.com/view/DCS_func_addGroup), I came up with 
this very basic demo.

```lua
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
```



### Directing AI to do things. TODO:

Baby steps...

### Spawn and dispatch units based on zone layouts and emplacements. TODO:

I'm going to learn how to do that soon. 

### Save and Reload System. New Saves. Error Handling. Maybe ED Delivers before I'm to this point? TODO:

Jumping way out of order here, I already needed some [serialization](https://www.lua.org/pil/12.1.html) so I could dump 
the data from Phase 2 to the logs. I happen to know that Mist uses SLmod's implementation of serialization, and that's 
not too far away from Surrexen's and Pikey's serialization systems, so I'm just going to borrow that and make sure I put
their names on the contributor list.

Here's the functions that serialize the data. The first one is super basic. If there's a `tostring` to be called, It calls it. 
I was nearly clever enough to figure this much out, and then saw how mist fixed edge cases. 

```lua
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
```

For more complicated tables (edge-cases), with nested tables inside of them, there's this function taken from the same part of Mist. I've 
adapted style and variable names to match what I'm doing, but I typed it nearly word for word from the Mist Implementation.

I chose to only do the one-line serialization because extra white space costs bytes, and bytes add up, eventually. 
Hopefully that makes up for all the bytes I'm wasting elsewhere.

```lua
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
```

I'll probably need to re-visit this again once the mission state data is in its final form. 


### Adding the Economy. TODO: 

I know I want to do something with GDP being a formula of industrial capacity and population... not sure what yet...

### Making Decisions for RED and BLUE Ground & Air Troops. TODO:

What to attack, and with what, and how many? More small attacks, or large assault/counter-assaults? What types of activities? Airstrike, Artillery, Cruise Missile, Armored Assault, Infantry Assault, Scouting, search & rescue, strike, deep strike, CAS, CAP, BAI, Runway Attack, SEAD, DEAD, Show of Force, JTAC, Supply, (Attack/Capture/Repair/Sabotage/Adviser) Troop Transport... so many ideas... no clue how to make them happen yet. 

### Making things not run like crap. TODO:

What creative ways have we discovered to make DCS run like poop?

### What about players? TODO:

Oh, crap... someone's supposed to play this, aren't they?

### ∞

This is like writing a book. You never finish the book, you just stop writing.

### How do I make this for <map/region>

I need to create some instructions, and examples, and maybe a whole test suite for this system...