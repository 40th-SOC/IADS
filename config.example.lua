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
		["p-19 s-125 sr"] = true,	--SA-3 Search Radar
		["Kub 1S91 str"] = true,	--SA-6 Search and Track Radar
		["S-300PS 64H6E sr"] = true,	--SA-10 Search Radar
		["S-300PS 40B6MD sr"] = true,	--SA-10 Search Radar
		["SA-11 Buk SR 9S18M1"] = true,	--SA-11 Search Radar
		["55G6 EWR"] = true,		--Early Warning Radar
		["1L13 EWR"] = true,		--Early Warning Radar
		["Hawk sr"] = true,		--Hawk SAM Search Radar
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
	-- Used for threat matching.
	["HIGH_THREAT_INTERCEPTERS"] = {
		["MiG-29A"] = true,
		["F-14B"] = true,
		["MiG-29S"] = true,
		["MiG-31"] = true,
		["Su-27"] = true,
		["JF-17"] = true,
	},
	-- Groups that will NOT have interceptors launched against them.
	-- Useful for preventing attacks on tankers/AWACS/Drones.
	-- SAMs may still activate.
	["IGNORE_GROUPS"]  {
		"Some Group Name",
    },
    -- Tactical SAM engagment modifier.
    -- If this modifier is set to 1, the SAM will engage at max range.
    -- If it is set to 0.8, the SAM will engage at 80% of max range.
    -- Engageming at less than max range will make SAMs deadlier.
    ["RMAX_MODIFIER"] = 0.8,

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
	-- The zone in which SAMs will engage targets. 
	-- If not specified, uses `AIRSPACE_ZONE_POINTS`.
	-- If AIRSPACE_ZONE_POINTS is not specified, SAMs will fire on any valid targets, 
	-- regardless of position.
	["MISSILE_ENGAGMENT_ZONES"] = {
		["Northern AO"] = iads.util.borderFromGroupRoute("northern_ao"),
        ["Southern AO"] = iads.util.borderFromGroupRoute("southern_ao"),
	}
	-- The zone in which interceptors will be dispatched to engage targets. 
	-- If not specified, uses `AIRSPACE_ZONE_POINTS`.
	-- If AIRSPACE_ZONE_POINTS is not specified, fighters will launch on any valid targets, 
	-- regardless of position.
    ["FIGHTER_ENGAGEMENT_ZONES"] = {
		["Northern AO"] = iads.util.borderFromGroupRoute("northern_ao"),
        ["Southern AO"] = iads.util.borderFromGroupRoute("southern_ao"),
	},
	-- Use any AWACS units found in the mission as a search radar
	["USE_AWACS_RADAR"] = true,
	-- Helicopters will NOT have interceptors dispatched on them if they are detected under this height in feet.
	-- SAMs may still attack.
	-- Set this to `nil` to dispatch fighters on helos at any altitude.
	["HELO_DETECTION_FLOOR"] = 500,
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
	-- A list of non-continguous polygons that will be used as engagement zones.
	["FIGHTER_ENGAGEMENT_ZONES"] = {
		["Northern AO"] = iads.util.zoneFromLineDrawing("Author", "NorthernAO"),
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