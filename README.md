## IADS Script

<b>Requires MIST</b>

### About

This script simulates a modern integrated air defense system (IADS). Early-warning (EW) radars will alert tactical SAM sites when a target as near, as well as dispatch interceptors to engage threats. Communication between units is modelled as a distrubuted network, rather than any centrally located controllers.

Benefits:

- <b>Simulates air defense rollback:</b> destroying EW radars will "blind" this IADS, meaning it will not be able to activate tactical SAMs or dispatch interceptors for threats it cannot see.

- <b>Simplifies mission creation:</b> place EWR radars and "Uncontrolled" groups of jets, and the IADS script will dispatch interceptors when it detects threats. There is no need to set up trigger zones for interceptors.

- <b>Creates a dymanic SEAD environment:</b> Tactical SAMs will not illuminate until they have a valid target. This makes them more realistic and harder to kill.

- <b>Allows for radar evasion tactics:</b> Players can hide from the IADS by using terrain cover, which opens up new tactics (as opposed to trigger zones).

- <b>Good for long-running missions:</b> Interceptors can be set to respawn, so missions that run for several hours will continuously dispatch fighters throughout the mission.

- <b>Matches threats to aggressors:</b> with threat-matching enabled, the IADS will scale the response to a BLUFOR aggressor's level. For example, if a 4-ship of aggressor Hornets is detected, a 4-ship of MiG-29s might be dispatched, but 2-ship of aggressor Mirages will will trigger a 2-ship of MiG-21s.

- <b>Supports border configuration:</b> if a border option is specified, the IADS will ignore groups that are outside of the border. SAMs can be configure to ignore borders with the `SAMS_IGNORE_BORDERS` configuration option.

### Usage

To use the IADS script, download the contents of `iads.lua` and add a "DO SCRIPT FILE" action to your mission. Once the script is loaded, add a "DO SCRIPT" action with the following code:

```lua
iads.init()
```

Set any interceptor groups in the mission editor to <b>"Uncontrolled"</b>. Interceptor groups must have either the <b>"CAP" or "Intercept"</b> task set in the mission editor. Also, ensure they have weapons equipped!

### Configuration:

Add a trigger action <b>AFTER</b> the `iads.lua` script has been loaded, add a "DO SCRIPT" action. Any configuration options NOT specified will be set to their default (shown below).

These are the available configuration options:

```lua
iads.config = {
	-- Allows EWR units to control tactical SAM radars.
	-- If an EWR detects a target within a SAM battery's firing range, it will tell the SAM to illuminate and engage.
	-- Tactical SAMs will be off until they have a target to fire at.
	["ENABLE_TACTICAL_SAMS"] = true,
	-- The maximum number of interceptor groups that can be airborne at one time.
	["MAX_INTERCEPTOR_GROUPS"] = 2,
	-- Pull the MAX_INTERCEPTOR_GROUPS value from a flag instead.
	-- This makes it easier to control how many groups are in the air via triggers.
	-- Set this value to a corresponding flag number and then use a "SET FLAG VALUE" action to control the value.
	["MAX_INTERCEPTOR_GROUPS_FLAG"] = nil,
	-- Whether or not the IADS scales its response to the type and quantity of target aircraft.
	-- For example, low-threat interceptors (F-5s, MiG-21s) will be dispatched against A-10s, but MiG-29s will be dispatched against hornets.
	["ENABLE_THREAT_MATCH"] = true,
	-- How often the IADS will reset its detected targets.
	-- Increase this to have more time between dispatching interceptors, decrease it to dispatch interceptors more frequently.
	["REINFORCEMENT_INTERVAL"] = 1500,
	-- Respawn interceptors.
	-- Currently only works if all remaining members of the interceptor group land at an airfield.
	["RESPAWN_INTERCEPTORS"] = true,
	-- Search radars that the IADS can use as EWR sites.
	-- If these search radars are part of a Tactical SAM group, they will NOT be able to act as EWR sites.
	["VALID_SEARCH_RADARS"] = {
		["p-19 s-125 sr"] = true,       --SA-3 Search Radar
		["Kub 1S91 str"] = true,        --SA-6 Search and Track Radar
		["S-300PS 64H6E sr"] = true,    --SA-10 Search Radar
		["S-300PS 40B6MD sr"] = true,   --SA-10 Search Radar
		["SA-11 Buk SR 9S18M1"] = true, --SA-11 Search Radar
		["55G6 EWR"] = true,            --Early Warning Radar
		["1L13 EWR"] = true,            --Early Warning Radar
		["Hawk sr"] = true,             --Hawk SAM Search Radar
	},
	-- Tactical SAM batteries.
	-- Groups with these units will have their AI shut off until an EWR site instructs them to illuminate.
	["TACTICAL_SAM_WHITELIST"] = {
		["SNR_75V"] = true,                --SA2
		["Kub 1S91 str"] = true,           --SA6
		["snr s-125 tr"] = true,           --SA3
		["SA-11 Buk LN 9A310M1"] = true,   --SA11,
		["Hawk tr"] = true,                --Hawk
	},
	-- Groups that will NOT have interceptors launched against them.
	-- Useful for preventing attacks on tankers/AWACS/Drones.
	-- SAMs may still activate.
	["IGNORE_GROUPS"]  {
		"Some Group Name",
    },
    -- If definded the IADS will only engage targets within the polygon
    -- defined by a table of vec2 points
    ["AIRSPACE_ZONE_POINTS"] = iads.util.borderFromGroupRoute("BorderGroup"),
	-- Routes that will be tasked by the IADS.
	-- These routes will be backfilled in the event that a patrolling group
	-- gets tasked with an intercept, or if they RTB for fuel.
	["PATROL_ROUTES"] = {
		["Eastern CAP"] = iads.util.routeFromGroup("Eastern Patrol"),
		["Western CAP"] = iads.util.routeFromGroup("Western Patrol")
	},
	["CAP_FLIGHT_BINGO_PERCENT"] = 0.30,
	-- How often to check CAP flight fuel statuses.
	["CAP_FLIGHT_FUEL_CHECK_INTERVAL"] = 300,
	-- A list of non-continguous polygons that will be used as engagement zones.
    -- Default is nil.
	["MISSILE_ENGAGMENT_ZONES"] = {
		["Northern AO"] = iads.util.borderFromGroupRoute("northern_ao"),
        ["Southern AO"] = iads.util.borderFromGroupRoute("southern_ao"),
	}
	-- A list of non-continguous polygons that will be used as engagement zones.
    -- Default is nil.
    ["FIGHTER_ENGAGEMENT_ZONES"] = {
		["Northern AO"] = iads.util.borderFromGroupRoute("northern_ao"),
        ["Southern AO"] = iads.util.borderFromGroupRoute("southern_ao"),
	},
	-- Use any AWACS units found in the mission as a search radar
	["USE_AWACS_RADAR"] = true,
	-- Helicopters will NOT have interceptors dispatched on them if they are detected under this height in feet.
	-- SAMs may still attack.
	-- Set this to ignore helicopters below an AGL altitude.
	-- Default is nil.
	["HELO_DETECTION_FLOOR"] = 500,
	-- Set this to ignore fixed-wing aircraft below an AGL altitude.
	["FIXED_WING_DETECTION_FLOOR"] = 500,
	-- Airframes are able to refuel from a tanker on bingo.
	["REFUEL_CAPABLE_AIRFRAMES"] = {
		["MiG-31"] = true,
		["Su-33"] = true,
		["M-2000C"] = true,
		["JF-17"] = true,
		["F-14B"] = true,
		["F-15C"] = true,
		["F-15E"] = true,
		["F-16C_50"] = true,
		["F/A-18C"] = true,
	}
	-- When enabled, SAM sites and search radars will try to defend from incoming anti-radiation missiles.
	-- Sites will stop emitting for a given period of time.
	-- This time period is set by the SAM_DEFENSE_TIMEOUT_RANGE parameter.
	["ENABLE_SAM_DEFENSE"] = false,
    -- How long SAM sites will turn off after being targetd by an ARM, in a low-high range.
	-- Default low is 4 minutes, high is 20 minutes
	["SAM_DEFENSE_TIMEOUT_RANGE"] = {240, 1200},
	-- These types of radars will not try to defend themselves from incoming ARMs.
	-- This allows advanced SAM systems to target ARM missiles (ie Patriot and SA10).
	-- Only applies if ENABLE_SAM_DEFENSE is set to true.
	["SAM_SUPPRESSION_EXEMPT_RADARS"] = {
		["S-300PS 64H6E sr"] = true,	--SA-10 Search Radar
		["S-300PS 40B6MD sr"] = true,	--SA-10 Search Radar
		["S-300PS 40B6M tr"] = true,    --SA-10 Track Radar
		["Patriot str"] = true,         --Patriot str
	},
}

-- Call this AFTER setting configuration options
iads.init()

-- Example of adding an interceptor group after initializing the IADS.
-- In this example, we activate a group, then provide the group's name
-- and home airbase id.
timer.scheduleFunction(function()
	local group = Group.getByName("LateActivation")

	group:activate()

	iads.addInterceptorGroup(group:getName(), Airbase.getByName("Kutaisi"):getID())
end, nil, timer.getTime() + 10)

-- To add a custom respawn handler, provide a callback function like so:
function myCustomShutdownHandler(groupName)
	trigger.action.outText(string.format("Custom handler. Group name %s", groupName), 30)
end

iads.onInterceptorShutdown(myCustomShutdownHandler)
```

## Development

Set this in your `<DCS install directory>\Scripts\MissionScripting.lua`

```lua
do
    __DEV_ENV = true
    -- sanitizeModule('os')
    -- sanitizeModule('io')
    -- sanitizeModule('lfs')
    require = nil
    loadlib = nil
end
```

Add this to a "DO SCRIPT" action in your mission to reload the scripts every time the mission starts.

```lua
dofile(lfs.writedir()..[[..\..\IADS\iads.lua]])
```
