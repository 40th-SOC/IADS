iads = {}

iads.util = {}

do
    local configDefaults = {
        ["ENABLE_TACTICAL_SAMS"] = true,
        ["MAX_INTERCEPTOR_GROUPS"] = 2,
        ["ENABLE_THREAT_MATCH"] = true,
        ["REINFORCEMENT_INTERVAL"] = 1500,
        ["RESPAWN_INTERCEPTORS"] = true,
        ["MAX_INTERCEPTOR_GROUPS_FLAG"] = nil,
        ["VALID_SEARCH_RADARS"] = {
            ["p-19 s-125 sr"] = true,		--SA-3 Search Radar
            ["Kub 1S91 str"] = true,	    --SA-6 Search and Track Radar
            ["S-300PS 64H6E sr"] = true,	--SA-10 Search Radar
            ["S-300PS 40B6MD sr"] = true,	--SA-10 Search Radar
            ["SA-11 Buk SR 9S18M1"] = true,	--SA-11 Search Radar
            ["55G6 EWR"] = true,			--Early Warning Radar
            ["1L13 EWR"] = true,			--Early Warning Radar
            ["Hawk sr"] = true,				--Hawk SAM Search Radar
            ["Patriot str"] = true,         --Patriot str
            ["RLS_19J6"] = true,             --SA-5 SR
        },
        ["TACTICAL_SAM_WHITELIST"] = {
            ["SNR_75V"] = true,                --SA2
            ["Kub 1S91 str"] = true,           --SA6
            ["snr s-125 tr"] = true,           --SA3
            ["SA-11 Buk LN 9A310M1"] = true,   --SA11,
            ["Hawk tr"] = true,                --Hawk
        },
        ["HIGH_THREAT_INTERCEPTERS"] = {
            ["MiG-29A"] = true,
            ["F-14B"] = true,
            ["MiG-29S"] = true, 
            ["MiG-31"] = true, 
            ["Su-27"] = true,
            ["JF-17"] = true,
        },
        ["IGNORE_GROUPS"] = nil,
        ["RMAX_MODIFIER"] = 1,
        ["IGNORE_SAM_GROUPS"] = nil,
        ["AIRSPACE_ZONE_POINTS"] = nil,
        ["SAMS_IGNORE_BORDERS"] = false,
        ["MISSILE_ENGAGMENT_ZONE"] = nil,
        ["FIGHTER_ENGAGMENT_ZONE"] = nil,
        ["USE_AWACS_RADAR"] = true,
        ["HELO_DETECTION_FLOOR"] = nil,
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
        },
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
        ["FIGHTER_ENGAGEMENT_ZONES"] = nil, 
        ["CAP_FLIGHT_FUEL_CHECK_INTERVAL"] = 300,
    }

    local THREAT_LEVELS = {
        ["LOW"] = 1,
        ["MEDIUM"] = 2,
        ["HIGH"] = 3,
        ["ULTRA"] = 4,
    } 

    -- Lookup for determining which type of interceptors to dispatch and how many in the group.
    -- First item is the threat classification for a 2-ship (or less), second item is 3+-ship
    -- For example: LOW threats always get a 2-ship group of either F-5s or MiG-21s
    local THREAT_MATRIX = {
        ["A-10C"] = {
            THREAT_LEVELS.LOW,
            THREAT_LEVELS.LOW,
        },
        ["AV8BNA"] = {
            THREAT_LEVELS.LOW,
            THREAT_LEVELS.LOW,
        },
        ["M-2000C"] = {
            THREAT_LEVELS.LOW,
            THREAT_LEVELS.MEDIUM, 
        }
    }

    local SAM_STATES = {
        ["ACTIVE"] = 1,
        ["INACTIVE"] = 2,
        ["DEFENDING"] = 3,
    }

    -- State
    local searchRadars = {}

    local tacticalSAMs = {}

    local uniqueDetectedGroups = {}

    local redAirCount = 0

    local internalConfig = {}

    local patrolRouteStatus = {}

    local fighterInventory = {}

    local activeEngagments = {}

    local homeAirbaseLookup = {}

    local airbaseLookup = {}

    -- Stores weapon IDs to prevent defending from the sam missile multiple times
    -- { [objId]: true }
    local acknowledgedMissiles = {}

    local function log(tmpl, ...)
        local txt = string.format("[IADS] " .. tmpl, ...)

        if __DEV_ENV == true then
            trigger.action.outText(txt, 30)
        end

        env.info(txt)
    end

    local function debugTable(tbl)
        log(mist.utils.tableShow(tbl))
    end

    local function buildConfig()
        local cfg = mist.utils.deepCopy(configDefaults)
        
        if iads.config then
            for k,v in pairs(iads.config) do
                cfg[k] = v
            end

            if iads.config.MAX_INTERCEPTOR_GROUPS_FLAG then
                local val = trigger.misc.getUserFlag(iads.config.MAX_INTERCEPTOR_GROUPS_FLAG)
                cfg.MAX_INTERCEPTOR_GROUPS = val

                log("Set MAX_INTERCEPTOR_GROUPS from user flag: %s", val)
            end
        end

        return cfg
    end

    local function hasValue(tab, val)
        for index, value in ipairs(tab) do
            if value == val then
                return true
            end
        end

        return false
    end

    local function setRadarState(params)
        if not params.group:isExist() then
            return
        end
    
        params.group:enableEmission(params.enabled)
    
        log("%s radar for %s", params.enabled and 'Enabling' or 'Disabling', params.group:getName())
    end

    local function isIgnoredGroup(groupName)
        if internalConfig.IGNORE_SAM_GROUPS then
            if internalConfig.IGNORE_SAM_GROUPS[groupName] ~= nil then
                log("Ignoring SAM group %s", groupName)
                return true
            end
        end

        return false
    end

    local function getAvgPointForGroup(group)
            -- Store average positions to enable defensive actions
        local units = group:getUnits()
        local points = {}
        for i,u in ipairs(units) do
            table.insert(points, u:getPoint())
        end

       return mist.getAvgPoint(points)
    end

    local function addSearchRadar(unit)
        local record = { 
            unit=unit, 
            state=SAM_STATES.ACTIVE, 
            name=unit:getName(), 
            avgPoint=getAvgPointForGroup(unit:getGroup()) ,
        }
        table.insert(searchRadars, record)
    end

    local function buildSAMDatabase()
        local allGroups = coalition.getGroups(coalition.side.RED, Group.Category.GROUND)

        for i, group in pairs(allGroups) do
            if not isIgnoredGroup(group:getName()) then
                for i, unit in pairs(group:getUnits()) do
                    if internalConfig.VALID_SEARCH_RADARS[unit:getTypeName()] == true then
                        addSearchRadar(unit)
                    end
    
                    if internalConfig.TACTICAL_SAM_WHITELIST[unit:getTypeName()] == true  then
                        if internalConfig.ENABLE_TACTICAL_SAMS then
                            setRadarState({ group=group, enabled=false })
                        end
                        table.insert(tacticalSAMs, { unit=unit, state=SAM_STATES.INACTIVE, name=unit:getName(), avgPoint=getAvgPointForGroup(group) })
                        break
                    end
                end
            end
        end

    end

    local function addAWACSRadars()
        local awacs = coalition.getServiceProviders(coalition.side.RED, coalition.service.AWACS)

        if not awacs or table.getn(awacs) == 0 then
            log("No AWACS found")
            return
        end


        for i,unit in ipairs(awacs) do
            -- EWR sites come through as AWACS. 
            -- Ensure no duplicates by checking for the airplane type.
            if unit:getGroup():getCategory() == Unit.Category.AIRPLANE then
                log("Found AWACS %s; adding as search radar", unit:getName())
                addSearchRadar(unit)
            end
        end
    end

    local function buildInterceptorDatabase()
        for i,c in ipairs(env.mission.coalition.red.country) do
            if (c.plane) then
                for i,group in ipairs(c.plane.group) do
                    local isPlayer = group.units[1].skill == "Client" or group.units[1].skill == "Player"
                    if (group.task == "CAP" or group.task == "Intercept") and not isPlayer and not group.lateActivation then
                        local groupName =  env.getValueDictByKey(group.name)
                        local gameGroup = Group.getByName(groupName)

                        table.insert(fighterInventory, groupName)
                        -- Store the home airbase so we can easily figure where
                        -- they need to RTB when out of gas.
                        local airbaseId = group.route.points[1].airdromeId
                        homeAirbaseLookup[groupName] = airbaseId
                    end
                end
            end
        end

        log("Fighter groups found: %s", mist.utils.tableShow(fighterInventory))
    end

    local function buildAirbaseDatabase()
        for i,airbase in ipairs(coalition.getAirbases(coalition.side.RED)) do
            local id = airbase:getID()
            local name = airbase:getName()

            airbaseLookup[id] = name
        end
    end

    -- Stolen from the mist development branch:
    -- https://github.com/mrSkortch/MissionScriptingTools/compare/development
    local function getHeadingPoints(point1, point2, north) 
        if north then 
            return mist.utils.getDir(mist.vec.sub(mist.utils.makeVec3(point2), mist.utils.makeVec3(point1)), (mist.utils.makeVec3(point1)))
        else
            return mist.utils.getDir(mist.vec.sub(mist.utils.makeVec3(point2), mist.utils.makeVec3(point1))) 
        end
    end

    local function isSEADMissile(weapon)
        -- local missile = weapon:getTypeName()
        local description = weapon:getDesc()
        return description.guidance == Weapon.GuidanceType.RADAR_PASSIVE
    end

    local function ackMissile(weaponName)
        acknowledgedMissiles[weaponName] = true
    end

    local function isAckedMissile(weaponName)
        return acknowledgedMissiles[weaponName] ~= nil
    end

    local function defendSAMGroup(groupPoint, unit, weapon)
        local weaponId = weapon:getName()

        if isAckedMissile(weaponName) then
            return false
        end

        local dist = mist.utils.metersToNM(mist.utils.get3DDist(weapon:getPoint(), groupPoint))

        if dist < 30 then
            -- The direction the missile is travelling
            local weaponHeading = mist.getHeading(weapon)
            log("are we doing this block?")
            -- The heading that the missile would need to be traveling to impact the target
            local interceptHeading = getHeadingPoints(weapon:getPoint(), groupPoint, true)
    
            local deltaHeading = math.abs(weaponHeading - interceptHeading) 
            -- `deltaHeading` is in radians. .01 means the missile is heading right for the target
            if deltaHeading < 0.1 then
                local group = unit:getGroup()
                log("ARM %s inbound at %s, defending", weaponId, group:getName())
                setRadarState({ group=group, enabled=false })
                ackMissile(weaponId)
                return true
            end  
        end

        return false
    end

    local function defendEmitters(collection, weapon)
        for i,data in ipairs(collection) do
            -- Guarding against a unit being dead
            local unit = Unit.getByName(data.name)
            if unit then
                local shouldDefend = true
                if internalConfig.SAM_SUPPRESSION_EXEMPT_RADARS then
                    local typeName = unit:getTypeName()
                    -- Certain SAM systems are better served by staying online to try and shoot down
                    -- anti-radiation missiles. Patriots and SA-10s, for example, have no problem knocking down
                    -- pre-briefed HARMs.
                    if internalConfig.SAM_SUPPRESSION_EXEMPT_RADARS[typeName] then
                        log("Radar %s in group %s is suppression exempt", typeName, unit:getGroup():getName())
                        ackMissile(weapon:getName())
                        shouldDefend = false
                    end
                end

                local didDefend = false
                
                if shouldDefend then
                    didDefend = defendSAMGroup(data.avgPoint, unit, weapon)
                end
         
                if didDefend then
                    local groupName = data.unit:getGroup():getName()
                    collection[i].state = SAM_STATES.DEFENDING
                    local minTimeout = internalConfig.SAM_DEFENSE_TIMEOUT_RANGE[1]
                    local maxTimeout = internalConfig.SAM_DEFENSE_TIMEOUT_RANGE[2]
                    
                    local suppressionTime = math.random(minTimeout, maxTimeout)
                    log("SAM %s disabled for %s seconds", groupName, suppressionTime)
                    timer.scheduleFunction(function()
                        -- Once set back to INACTIVE, this site goes back into the
                        -- pool of radars that can be activated 
                        collection[i].state = SAM_STATES.INACTIVE
                        log("SAM defense for %s ended", groupName)
                    end, nil, timer.getTime() + suppressionTime)
                end
            end
        end
    end

    local function defendSAMSites(detectedARMs)
        for i,threat in ipairs(detectedARMs) do
            local weapon = threat.weapon
            
            if not isAckedMissile(weapon:getName()) then
                -- log("ARM %s detected by %s", weapon:getName(), threat.detectedBy)
                -- TODO: combine this into a single table
                -- Note: time-complexity here is (number ARMs * number tactical SAMS) + (number ARMS * search radars).
                -- Once the ARMs start homing in and sites start to defend, time-complexity goes down.
                defendEmitters(tacticalSAMs, weapon)
                defendEmitters(searchRadars, weapon)
            end
        end
    end

    local function findDetectedTargets()
        local detectedUnits = {}
        local detectedARMs = {}

        for i, radar in ipairs(searchRadars) do
            local searchRadar = Unit.getByName(radar.name)

            if searchRadar ~= nil then
                local group = searchRadar:getGroup()
                local groupName = group:getName()
                local controller = group:getController()
                local detectedTargets = controller:getDetectedTargets()
                for k,v in pairs (detectedTargets) do

                    -- v.object can be undefined in some situations
                    if v.object then
                        if v.object:getCategory() == Object.Category.WEAPON and isSEADMissile(v.object) then
                            table.insert(detectedARMs, { weapon = v.object, detectedBy = groupName})
                        else
                            table.insert(detectedUnits, { target = v.object, detectedBy = groupName })
                        end
                    end
                end 
            end
        end

        return detectedUnits, detectedARMs
    end

    local function findAvailableInterceptors(targetPos)
        local orderedInterceptors = {}

        for i,groupName in ipairs(fighterInventory) do
            local group = Group.getByName(groupName)

            if group then
                -- Only select groups that are not engaged
                if not activeEngagments[group:getName()] then
                    local units = group:getUnits()
                    local inAir = units[1]:inAir()
                    local dist = mist.utils.get2DDist(targetPos, units[1]:getPoint())
                    table.insert(orderedInterceptors, { distance=dist, group=group, airborne=inAir })
                end
            end
        end

        table.sort(orderedInterceptors, function(a,b)
            -- Lua has weird rules about sorting function validity.
            -- Do these nil checks to give a valid sort function.
            if a == nil and b == nil then return false end
            if a == nil then return true end
            if b == nil then return false end

            if a.airborne == true and b.airborne == false then
                return true
            end

            if a.airborne == false and b.airborne == true then
                return false
            end

            return a.distance < b.distance
        end)

        -- Returns a table with { group=Group, dist=Number, airborne=bool }
        return orderedInterceptors
    end

    local function getThreatLevel(unit)
        local group = unit:getGroup()
        local category = group:getCategory()
        local type = unit:getTypeName()

        if category == Group.Category.HELICOPTER then
            -- Helos are always LOW threat
            return THREAT_LEVELS.LOW
        end
        -- Hopefully :getSize() returns the amount of people actually slotted,
        -- not the amount available in the mission....
        local strength = group:getSize()

        local overrides = THREAT_MATRIX[type]

        -- Target is HIGH threat unless we have specified overrides
        local level = THREAT_LEVELS.HIGH

        if overrides ~= nil then
            if strength > 2 then
                level = overrides[2]
            else
                level = overrides[1]
            end
        else
            -- No matrix found, scale up to ULTRA if the target is larger than a 2-ship
            if strength > 2 then
            level = THREAT_LEVELS.ULTRA
            end
        end

        return level
    end

    local function sortByThreatLevel(availableGroups, targetThreatLevel)
        local sortedGroups = {}

        for i,g in ipairs(availableGroups) do
            -- availableGroups is a list with {group=Group} members.
            -- Really wish Lua had a type system.
            local group = g.group
            local type = group:getUnits()[1]:getTypeName()
            local isAdvanced = false
            local level = THREAT_LEVELS.LOW

            if internalConfig.HIGH_THREAT_INTERCEPTERS[type] then
                isAdvanced = true
                level = THREAT_LEVELS.HIGH
            end

            if group:getSize() > 2 then
                -- This will increment from LOW -> MEDIUM for 3rd gen fighters,
                --  and HIGH -> ULTRA for 4th gen
                level = level + 1
            end

            table.insert(sortedGroups, { level=level, group=group })
        end

        table.sort(sortedGroups, function(a,b) return math.abs(targetThreatLevel - a.level) < math.abs(targetThreatLevel - b.level) end)

        return sortedGroups
    end

    local function isThreatMatch(candidateLevel, targetThreatLevel)
        if targetThreatLevel > THREAT_LEVELS.HIGH then
            -- Target is a 4-ship of advanced fighters, send any group
            return true
        end

        if targetThreatLevel == THREAT_LEVELS.LOW and candidateLevel == THREAT_LEVELS.LOW then
            -- Always do low on low
            return true
        end

        if targetThreatLevel == THREAT_LEVELS.MEDIUM and candidateLevel < THREAT_LEVELS.HIGH then
            -- Target is a Gen3 fighter (Mirage).
            -- Send a LOW or MEDIUM group against a MEDIUM target.
            return true
        end

        if targetThreatLevel == THREAT_LEVELS.HIGH and candidateLevel < THREAT_LEVELS.ULTRA then
            -- Target is a 2-ship of advanced fighters. 
            -- Send a 2-ship of advanced fighters, or a 4-ship of regular fighters.
            return true
        end

        return false
    end

    local function taskGroupWithPatrol(group, routeName, route)
        local controller = group:getController()

        controller:setCommand({
            id = 'Start',
            params = {},
        })

        -- Setting a delay here seems to work for some reason.
        -- Otherwise routes will be ignored.
        timer.scheduleFunction(function() 
            mist.goRoute(group:getName(), route)
            controller:setOption(AI.Option.Air.id.ROE, AI.Option.Air.val.ROE.RETURN_FIRE)
        end, nil, timer.getTime() + 60)

        log("Tasking group %s with patrol route %s", group:getName(), routeName)

        patrolRouteStatus[routeName] = group
    end

    local function iadsHasCapacity()
        return redAirCount < internalConfig.MAX_INTERCEPTOR_GROUPS
    end

    local function dispatchPatrolRoutes()
        if not internalConfig.PATROL_ROUTES then
            return
        end

        -- Keeps track of the groups already tasked to avoid assigning the same group twice.
        local taskedGroups = {}

        for routeName,route in pairs(internalConfig.PATROL_ROUTES) do
            if patrolRouteStatus[routeName] == nil then
                local startPoint = route[2]
                local available = findAvailableInterceptors(startPoint)
    
                if #available > 0 then
                    for i,a in ipairs(available) do
                        local group = a.group
                        local groupName = group:getName()

                        if not taskedGroups[groupName] then
                            taskedGroups[groupName] = true
                            taskGroupWithPatrol(group, routeName, route)
                            break
                        end
                    end
                else
                    log("No fighters available to dispatch for patrol route %s", routeName)
                end
            end
        end
    end

    local function backfillCAPRoute(prevGroup)
        local needsBackfill = false
        local patrolRouteName = ""
            -- See if this group was on a patrol
        for routeName,patrolGroup in pairs(patrolRouteStatus) do
            if prevGroup:getName() == patrolGroup:getName() then
                needsBackfill = true
                patrolRouteName = routeName
                patrolRouteStatus[routeName] = nil
                break
            end
        end

        if not needsBackfill then
            return
        end

        -- We assume that the previous group tasked with the patrol is a good
        -- indicator of the route position.
        -- Saves a wonky lookup to find the route starting point from the internalConfig.
        local routePos = prevGroup:getUnits()[1]:getPoint()
        local available = findAvailableInterceptors(routePos)

        for i,interceptorGroup in ipairs(available) do
            if not interceptorGroup.airborne then
                -- Send the first group that is parked
                for name,route in pairs(internalConfig.PATROL_ROUTES) do
                    if name == patrolRouteName then
                        log("Backfilling patrol route %s", patrolRouteName)
                        taskGroupWithPatrol(interceptorGroup.group, patrolRouteName, route)
                        break
                    end
                end
                
                break
            end
        end

    end

    local function launchInterceptors(target, threatLevel)
        local interceptGroup = nil

        local availableInterceptors = findAvailableInterceptors(target:getPoint())

        if table.getn(availableInterceptors) > 0 then
            if internalConfig.ENABLE_THREAT_MATCH then
                local sorted = sortByThreatLevel(availableInterceptors, threatLevel)
                for i,interceptor in ipairs(sorted) do
                    if isThreatMatch(interceptor.level, threatLevel) then
                        interceptGroup = interceptor
                        -- Stop looping over interceptor groups
                        break
                    end
                end
            else
                -- Don't match threats, just send the closest group
                interceptGroup = availableInterceptors[1]
            end
        end

        if not interceptGroup then
            -- No interceptors found, nothing to dispatch
            log("No valid interceptors found")
            return false
        end

        local group = interceptGroup.group
        local controller = group:getController()
        controller:setCommand({
            id="Start",
            params={}
        })

        controller:setTask({
            id="AttackGroup",
            params={
                groupId = target:getID(),
            }
        })

        controller:setOption(AI.Option.Air.id.ROE, AI.Option.Air.val.ROE.OPEN_FIRE_WEAPON_FREE)
        activeEngagments[group:getName()] = true

        log("Tasking %s, Target: %s", group:getName(), target:getGroup():getName())

        if  internalConfig.PATROL_ROUTES and iadsHasCapacity() then
            backfillCAPRoute(group)
        else
            log("Skipping patrol backfill; No routes or IADS at capacity")
        end

        return true
    end

    local function possiblyDisableSAM(groupName, index)
        local group = Group.getByName(groupName)
        local controller = group and group:getController()

        if controller then
            local sam = tacticalSAMs[index]

            if sam.state == SAM_STATES.DEFENDING then
                -- This site is suppressed.
                -- It will be added back to the pool once the suppression effect has timed out.
                mist.removeFunction(sam.timer)
                return
            end

            if table.getn(controller:getDetectedTargets()) == 0 then
                setRadarState({ group=group, enabled=false })
                sam.state = SAM_STATES.INACTIVE
                mist.removeFunction(sam.timer)
            end
        end
    end

    local function activateNearbySAMs(target)
        for i,data in ipairs(tacticalSAMs) do
            -- Guarding against a unit being dead
            local unit = Unit.getByName(data.name)

            if unit and data.state == SAM_STATES.INACTIVE then
                local sensors = unit:getSensors() and unit:getSensors()[1]

                if sensors then
                    local trackRadar = sensors[1]
                    local rmax = trackRadar.detectionDistanceAir.upperHemisphere.headOn
                    local dist = mist.utils.get2DDist(target:getPoint(), unit:getPoint())
    
                    -- Wait until the target is closer. 
                    -- This ensures that SAMs are almost ready to fire when they turn on.
                    if dist < (rmax * internalConfig.RMAX_MODIFIER) then
                        local group = unit:getGroup()
                        setRadarState({ group=group, enabled=true })
                        tacticalSAMs[i].state = SAM_STATES.ACTIVE
                        tacticalSAMs[i].timer = mist.scheduleFunction(possiblyDisableSAM, { group:getName(), i }, timer.getTime() + 10, 10, nil)
                    end
                end
            end
        end
    end

    local function unitInsideZone(target, points)
        if not target then
            return false
        end

        return mist.pointInPolygon(target:getPoint(), points)
    end

    -- https://forums.eagle.ru/topic/188177-moose-get-altitude-over-the-ground-instead-of-over-the-sea/?do=findComment&comment=3624894
    local function getAGL(unit)
        local pos = unit:getPoint()
        local aglMeters = pos.y - land.getHeight({x=pos.x, y = pos.z})
        local aglFeet = mist.utils.metersToFeet(aglMeters)

        return aglFeet
    end

    local function isValidTarget(target)
        if not target then
            return false
        end

        if target and target:getCategory() ~= Object.Category.UNIT then
            return false
        end

        local isValid = true
        local detectionZone = nil

        if internalConfig.FIGHTER_ENGAGEMENT_ZONES then
            for zone,points in pairs(internalConfig.FIGHTER_ENGAGEMENT_ZONES) do
                isValid = unitInsideZone(target, points)
                detectionZone = zone
                if isValid then
                    -- No need to check other zones
                    break
                end
            end
        elseif internalConfig.AIRSPACE_ZONE_POINTS then
            isValid = unitInsideZone(target, internalConfig.AIRSPACE_ZONE_POINTS)
        end

        if internalConfig.HELO_DETECTION_FLOOR and target:getGroup():getCategory() == Group.Category.HELICOPTER then
            local agl = getAGL(target)
            if  agl < internalConfig.HELO_DETECTION_FLOOR then
                isValid = false
            end
        end

        return isValid, detectionZone
    end

    local function targetIsIgnored(target)
        if internalConfig.IGNORE_GROUPS then
            for i,v in ipairs(internalConfig.IGNORE_GROUPS) do
                if target.getGroup and v == target:getGroup():getName() then
                    return true
                end
            end
        end

        return false
    end

    local function possiblyEngageWithSAMs(target)
        if targetIsIgnored(target) then
            return
        end
        -- Only engage if the user is using tactical SAMS
        if internalConfig.ENABLE_TACTICAL_SAMS then
            -- If the user has specified a missile engagement zone,
            -- check to make sure the target is within the zone before illuminating.
            -- Else, use the IADS borders as the engagment zone.
            local engagmentZone = nil
            local shouldEngage = true
            local detectionZone = nil

            if internalConfig.MISSILE_ENGAGMENT_ZONES then
                for zone,points in pairs(internalConfig.MISSILE_ENGAGMENT_ZONES) do
                    shouldEngage = unitInsideZone(target, points)
                    detectionZone = zone
                    if shouldEngage then
                        -- No need to check other zones
                        break
                    end
                end
            elseif internalConfig.AIRSPACE_ZONE_POINTS then
                shouldEngage, detectionZone = unitInsideZone(target, internalConfig.AIRSPACE_ZONE_POINTS)
            end

            if shouldEngage then
                activateNearbySAMs(target)
            end
        end
    end

    local function runIADS()
        local allTargets, antiRadiationMissiles = findDetectedTargets()

        if internalConfig.ENABLE_SAM_DEFENSE then
            defendSAMSites(antiRadiationMissiles)
        end

        for i,v in ipairs(allTargets) do
            local target = v.target

            possiblyEngageWithSAMs(target)

            local valid, detectionZone = isValidTarget(target) 
            if valid then

                local groupName = target:getGroup():getName()

                if uniqueDetectedGroups[groupName] == nil then
                    -- New threat group detected
                    local threatLevel = getThreatLevel(target)

                    uniqueDetectedGroups[groupName] = target

                    if targetIsIgnored(target) then
                        log("Ignoring detected group %s", groupName)
                        return 
                    end

                    local logStr = "New threat: %s, Level: %s, Detected by: %s"
                    if detectionZone then
                        logStr = logStr .. ". Zone: %s"
                    end
                    log(logStr, groupName, threatLevel, v.detectedBy, detectionZone)
                    
                    if iadsHasCapacity() then
                        local didLaunch = launchInterceptors(target, threatLevel)
                        -- Only increment if a group is taking off from an airbase
                        -- This should increment up to the MAX_RED_AIR_COUNT and no further.
                        if didLaunch then
                            redAirCount = redAirCount + 1;
                            log("Incremented red air count to %s", redAirCount)
                        end
                    else
                        log("Skipping launch; IADS at capacity")
                    end
                end
            end
        end
    end

    local function isKnownInterceptor(groupName)
        for i,name in ipairs(fighterInventory) do
            if groupName == name then
                return true
            end
        end

        return false
    end

    -- This should correct the available "capacity" for redfor interceptors.
    -- If a redfor interceptor group is killed or lands, decrement redAirCount.
    local function reconcileState()
        local aliveOrAirborn = 0

        -- Re-run config to respond to runtime config changes
        internalConfig = buildConfig()

        log("Reconciling state...")
        for i,group in ipairs(coalition.getGroups(coalition.side.RED, Group.Category.AIRPLANE)) do
            if group:isExist() and isKnownInterceptor(group:getName()) then
                local atLeastOneUnitAirborn = false
                
                for i,unit in ipairs(group:getUnits()) do
                    -- Don't count players. Counting players makes things too unpredictable.
                    -- Players can be on the ground, then two interceptors will spawn.
                    -- Then players take off and a total of n + 1 groups are airborne.
                    if unit:getPlayerName() == nil and unit:inAir() == true then
                        atLeastOneUnitAirborn = true
                        break
                    end
                end
        
                if atLeastOneUnitAirborn == true then
                    aliveOrAirborn = aliveOrAirborn + 1;
                end
            end
        end
        
        log("Current interceptor capacity: %s / %s", aliveOrAirborn, internalConfig.MAX_INTERCEPTOR_GROUPS)
        if aliveOrAirborn < internalConfig.MAX_INTERCEPTOR_GROUPS then
            redAirCount = aliveOrAirborn
            -- Reset this to ensure a group doesn't get to loiter if they have alreay been targeted
            uniqueDetectedGroups = {}
            activeEngagments = {}
        end
        acknowledgedMissiles = {}
        dispatchPatrolRoutes()
    end

    local customRespawnHandler = nil

    local function respawnInterceptors(group)
        -- Don't respawn anything but airplanes.
        if group:getCategory() ~= Group.Category.AIRPLANE then
            return
        end

        local respawn = true
        for i,u in ipairs(group:getUnits()) do
            local velocity = mist.vec.mag(u:getVelocity())  
            if velocity > 0 then
                respawn = false
                break
            end
        end

        if respawn == true then
            log("Group landed: %s. Restocking...", group:getName())

            if customRespawnHandler then
                log("Running custom respawn handler...")
                customRespawnHandler(group:getName())
            else
                mist.respawnGroup(group:getName(), true)
            end
        end
    end

    local function IADSEventHandler(event)
        local object = event.initiator
        if object == nil then
            return
        end

        if event.id == world.event.S_EVENT_ENGINE_SHUTDOWN then
            if object.getCoalition and object:getCoalition() == coalition.side.RED then
                local group = object:getGroup()

                if not group then
                    return 
                end

                if hasValue(fighterInventory, group:getName()) == false then
                    return
                end

                if internalConfig.RESPAWN_INTERCEPTORS then
                    respawnInterceptors(group)
                end
            end
        end
    end

    local function backfillLowFuelStates()
        for routeName,group in pairs(patrolRouteStatus) do
            if group then
                for i,unit in ipairs(group:getUnits()) do
                    if unit:getFuel() < internalConfig.CAP_FLIGHT_BINGO_PERCENT then
                        local controller = group:getController()
                        local tankerUnits = coalition.getServiceProviders(coalition.side.RED, coalition.service.TANKER)

                        if table.getn(tankerUnits) > 0 then
                            -- Only refuel if the airframe is capable of in-flight refueling
                            local isRefuelCapable = internalConfig.REFUEL_CAPABLE_AIRFRAMES[unit:getTypeName()] == true
                            if isRefuelCapable then
                                log("Unit %s is bingo. Group %s is refueling.", unit:getName(), group:getName())
                                controller:pushTask({
                                    id = 'Refueling', 
                                    params = {} ,
                                })
                                -- Break the loop early. 
                                -- Nothing else in the outer block will run.
                                break
                            else
                                log("Tanker found, but group %s is not capable of refueling", group:getName())
                            end
                        end

                        log("Unit %s is bingo. No tankers found, group %s is RTB.", unit:getName(), group:getName())

                        local homeAirbaseId = homeAirbaseLookup[group:getName()]
                        local base = Airbase.getByName(airbaseLookup[homeAirbaseId])
                        local point = base:getPoint()

                        local rtb = { 
                            id = 'Mission', 
                            params = { 
                                route = { 
                                    points = { 
                                        [1] = { 
                                            type = AI.Task.WaypointType.LAND, 
                                            airdromeId = homeAirbaseId, 
                                            action = AI.Task.TurnMethod.FIN_POINT, 
                                            x = point.x, 
                                            y = point.z, 
                                        }, 
                                    } 
                                }
                            } 
                        }

                        controller:setTask(rtb)
                        backfillCAPRoute(group)
                        -- Break units loop
                        break;
                    end
                end
            end
        end
    end

    function iads.init()
        -- This will ensure the server does not pause on errors.
        -- Warning: you need to check your DCS logs if you do not have this variable set.
        if not __DEV_ENV == true then
            env.setErrorMessageBoxEnabled(false)
        end

        internalConfig = buildConfig()

        -- log(mist.utils.tableShow(internalConfig.MISSILE_ENGAGMENT_ZONE))

        buildSAMDatabase()
        -- On the initial frame, the AWACS units have not registered themselves yet.
        -- Wait 1 second to give them time to initialize.
        -- Invoking addAWACSRadars on the first frame will result in an empty table.
        if internalConfig.USE_AWACS_RADAR then
            timer.scheduleFunction(addAWACSRadars, nil, timer.getTime() + 1)
        end
        buildInterceptorDatabase()
        buildAirbaseDatabase()
        dispatchPatrolRoutes()

        mist.scheduleFunction(reconcileState, nil, 10, internalConfig.REINFORCEMENT_INTERVAL)

        mist.scheduleFunction(runIADS, nil, 0, 10)
        mist.scheduleFunction(backfillLowFuelStates, nil, 0, internalConfig.CAP_FLIGHT_FUEL_CHECK_INTERVAL)

        trigger.action.outText("IADS script initialized", 30)
        -- log(mist.utils.tableShow(internalConfig))

        mist.addEventHandler(IADSEventHandler)
    end

    function iads.util.pointsFromTriggerZones(zones)
        local points = {}
        for i,zoneName in ipairs(zones) do
            local zone = trigger.misc.getZone(zoneName)
            local p2 = { x=zone.point.x, y=zone.point.z }
            table.insert(points, p2)
        end

        return points
    end

    function iads.util.routeFromGroup(groupName)
        local route = mist.getGroupRoute(groupName, true)

        if not route then
            log("Group not found: %s", groupName)
            return nil
        end

        return route
    end

    function iads.util.borderFromGroupRoute(groupName)
        local points = {}
        local route = mist.getGroupRoute(groupName, true)

        if not route then
            log("No group found for border route: %s", groupName)
            return points
        end

        for i,point in ipairs(route) do
            local p = {x=point.x, y=point.y}
            table.insert(points, p)
        end
        
        return points
    end

    -- TODO: drawing objects use an origin + offset to define shapes/vertices.
    -- Stick to using groups for border drawings for now, since they work as expected
    -- 
    -- function iads.util.zoneFromLineDrawing(layerName, drawingName)
    --     for i,layer in ipairs(env.mission.drawings.layers) do
    --         if layer.name == layerName then
    --             for i,obj in ipairs(layer.objects) do
    --                 if obj.name == drawingName then
    --                     if obj.primitiveType ~= "Line" or not obj.closed then
    --                         log("Invalid drawing object for zone; object %s must be a closed line drawing.", drawingName)
    --                     else
    --                         return obj.points
    --                     end
    --                 end
    --             end
    --         end
    --     end
    -- end

    function iads.addInterceptorGroup(groupName, aerodromeId)
        if not groupName then
            log("Could not add group. groupName not specified")
            return
        end

        if not aerodromeId then
            log("Could not add group. aerodromeId not specified")
            return
        end

        log("Adding interceptor group %s, home base id: %s", groupName, aerodromeId)
        table.insert(fighterInventory, groupName)
        homeAirbaseLookup[groupName] = aerodromeId
    end

    function iads.onInterceptorShutdown(fn)
        customRespawnHandler = fn
    end
end