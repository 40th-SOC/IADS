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
        ["RMAX_MODIFIER"] = 0.8,
        ["IGNORE_SAM_GROUPS"] = nil,
        ["AIRSPACE_ZONE_POINTS"] = nil
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

    local function log(tmpl, ...)
        local txt = string.format("[IADS] " .. tmpl, ...)

        if __DEV_ENV == true then
            trigger.action.outText(txt, 30)
        end

        env.info(txt)
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
    
        local alarmState = params.enabled and AI.Option.Ground.val.ALARM_STATE.RED or AI.Option.Ground.val.ALARM_STATE.GREEN
        params.group:getController():setOption(AI.Option.Ground.id.ALARM_STATE, alarmState)
    
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

    local function buildSAMDatabase()
        local allGroups = coalition.getGroups(coalition.side.RED, Group.Category.GROUND)

        for i, group in pairs(allGroups) do
            if not isIgnoredGroup(group:getName()) then
                for i, unit in pairs(group:getUnits()) do
                    if internalConfig.VALID_SEARCH_RADARS[unit:getTypeName()] == true then
                        table.insert(searchRadars, unit:getName())
                    end
    
                    if internalConfig.TACTICAL_SAM_WHITELIST[unit:getTypeName()] == true  then
                        if internalConfig.ENABLE_TACTICAL_SAMS then
                            setRadarState({ group=unit:getGroup(), enabled=false })
                        end
                        table.insert(tacticalSAMs, { unit=unit, state=SAM_STATES.INACTIVE, name=unit:getName() })
                        break
                    end
                end
            end
        end
    end

    local function buildInterceptorDatabase()
        for i,c in ipairs(env.mission.coalition.red.country) do
            if (c.plane) then
                for i,group in ipairs(c.plane.group) do
                    if (group.task == "CAP" or group.task == "Intercept") and not group.lateActivation then
                        local groupName =  env.getValueDictByKey(group.name)
                        local gameGroup = Group.getByName(groupName)

                        table.insert(fighterInventory, groupName)
                    end
                end
            end
        end

        log("Fighter groups found: %s", mist.utils.tableShow(fighterInventory))
    end

    local function findDetectedTargets()
        local detectedUnits = {}

        for i, radarName in ipairs(searchRadars) do
            local searchRadar = Unit.getByName(radarName)

            if searchRadar ~= nil then
                local group = searchRadar:getGroup()
                local controller = group:getController()
                local detectedTargets = controller:getDetectedTargets()
                for k,v in pairs (detectedTargets) do
                    table.insert(detectedUnits, { target = v.object, detectedBy = group:getName() })
                end 
            end
        end

        return detectedUnits
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

        for routeName,route in pairs(internalConfig.PATROL_ROUTES) do
            if patrolRouteStatus[routeName] == nil then
                local startPoint = route[2]
                local available = findAvailableInterceptors(startPoint)
    
                if #available > 0 then
                    local group = available[1].group
    
                    taskGroupWithPatrol(group, routeName, route)
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

        controller:setOption(AI.Option.Air.id.ROE, AI.Option.Air.val.ROE.WEAPON_FREE)
        activeEngagments[group:getName()] = true

        log("Tasking %s, Target: %s", group:getName(), target:getGroup():getName())

        if  internalConfig.PATROL_ROUTES and iadsHasCapacity() then
            backfillCAPRoute(group)
        else
            log("Skipping patrol backfill; IADS at capacity")
        end

        return true
    end

    local function possiblyDisableSAM(groupName, index)
        local group = Group.getByName(groupName)
        local controller = group and group:getController()

        if controller then
            if table.getn(controller:getDetectedTargets()) == 0 then
                setRadarState({ group=group, enabled=false })
                tacticalSAMs[index].state = SAM_STATES.INACTIVE
                mist.removeFunction(tacticalSAMs[index].timer)
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

    local function isValidTarget(target)
        if not target then
            return false
        end

        if target and target:getCategory() ~= Object.Category.UNIT then
            return false
        end

        if internalConfig.AIRSPACE_ZONE_POINTS ~= nil then
            local p = target:getPoint()

            if mist.pointInPolygon(p, internalConfig.AIRSPACE_ZONE_POINTS) then
                return true
            else
                return false
            end
        end

        return true
    end

    local function runIADS()
        local allTargets = findDetectedTargets()

        for i,v in ipairs(allTargets) do
            local target = v.target

            if isValidTarget(target) then
                if internalConfig.ENABLE_TACTICAL_SAMS then
                    activateNearbySAMs(target)
                end

                local groupName = target:getGroup():getName()

                if uniqueDetectedGroups[groupName] == nil then
                    -- New threat group detected
                    local threatLevel = getThreatLevel(target)

                    uniqueDetectedGroups[groupName] = target

                    if internalConfig.IGNORE_GROUPS then
                        for i,v in ipairs(internalConfig.IGNORE_GROUPS) do
                            if v == groupName then
                                log("Ignoring detected group %s", groupName)
                                return 
                            end
                        end
                    end

                    log("New threat: %s, Level: %s, Detected by: %s", groupName, threatLevel, v.detectedBy)
                    
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
        dispatchPatrolRoutes()
    end

    local function respawnInterceptors(group)
        -- Don't respawn anything but airplanes.
        if group:getCategory() ~= Group.Category.AIRPLANE then
            return
        end

        local respawn = true
        for i,u in ipairs(group:getUnits()) do
            if u:inAir() then
                respawn = false
                break
            end
        end

        if respawn == true then
            log("Group landed: %s. Restocking...", group:getName())
            mist.respawnGroup(group:getName(), true)
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



    function iads.init() 
        internalConfig = buildConfig()

        buildSAMDatabase()
        buildInterceptorDatabase()
        dispatchPatrolRoutes()

        mist.scheduleFunction(reconcileState, nil, 10, internalConfig.REINFORCEMENT_INTERVAL)

        mist.scheduleFunction(runIADS, nil, 0, 10)

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
    function iads.addInterceptorGroup(groupName)
        log("Adding interceptor group %s", groupName)
        table.insert(fighterInventory, groupName)
    end
end