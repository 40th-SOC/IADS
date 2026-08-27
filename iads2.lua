RedFlagIADS = {}

RedFlagIADS.util = {}


local cfg = {

}

local SAM_STATE = {
    ["ACTIVE"] = 1,
    ["INACTIVE"] = 2,
    ["DEFENDING"] = 3,
}

Sensor = {
    name = "",
    position = { x = 0, y = 0 },
    type = "",
    state = SAM_STATE.INACTIVE,
}
-- @param name: string
-- @param position: {x, y}
-- @param type: string
-- @param state: SAM_STATE
function Sensor:new(name, position, type, state)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.name = name
    obj.position = position
    obj.type = type
    return obj
end

Shooter = {
    name = "",
    position = { x = 0, y = 0 },
    type = "",
    state = SAM_STATE.INACTIVE,
}
-- @param name: string
-- @param position: {x, y}
-- @param type: string
-- @param state: SAM_STATE
function Shooter:new(name, position, type, state)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.name = name
    obj.position = position
    obj.type = type
    obj.state = state
    return obj
end

-- @param target: Track
function Shooter:engage(target)
    -- Run the engagement program.
    -- Get the sensors for this shooter unit
    -- Check the range against rmax modifier
    -- Set state to active
    -- Illuminate: params.group:enableEmission(params.enabled)
    -- Set a timer to turn off is you don't find anything
    -- Stretch: turn off if you see a HARM coming at you
end

Track = {
    name = "",
    position = { x = 0, y = 0 },
    type = "",
    isARM = false,
    lastSeen = 0,
}
-- @param name: string
-- @param position: {x, y}
-- @param type: string
-- @param state: string
function Track:new(name, position, type)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.name = name
    obj.position = position
    obj.type = type
    return obj
end

EngagementZone = {
    name = "",
    points = {},
}

-- @param name: string
-- @param points: { {x, y}, {x, y} }
function EngagementZone:new(name, points)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

-- @param point: {x, y}
function EngagementZone:contains(point)
    -- Check if the point is in the zone
end

-- Get the shooters in the zone
-- @returns {Shooter}
function EngagementZone:shooters()
    -- Get the shooters in the zone
end

local missileEngagementZones = {
    {
        EngagementZone:new("MEZ1", { { x = 0, y = 0 }, { x = 100, y = 100 } }),
    },
}

IADSSystem = {
    coalition = 0,
    name = "",
    sensors = {},
    shooters = {},
    tracks = {},
}

function IADSSystem:new(coalition, name)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.name = name
    obj.sensors = {}
    obj.shooters = {}
    obj.tracks = {}
    obj.coalition = coalition
    return obj
end

-- @param sensor: Sensor
function IADSSystem:addSensor(sensor)
    table.insert(self.sensors, sensor)
end

-- @param shooter: Shooter
function IADSSystem:addShooter(shooter)
    table.insert(self.shooters, shooter)
end

function IADSSystem:collectSensors()
    -- Get EW radars
end

function IADSSystem:collectShooters()
    -- Get all valid SAMs and put them in a database
    -- Organize them into missile engagement zones
end

function IADSSystem:addAWACSRadars()
    -- Add AWACS radars to the database
end

-- Disable tactical SAM emitters. Use this on startup.
function IADSSystem:disableEmitters()

end

-- @param allTargets: {Track}
-- @param antiRadiationMissiles: {Track}
function IADSSystem:upsertTracks(allTargets, antiRadiationMissiles)
    -- Upsert tracks
    -- If the track is not in the database, add it
    -- If the track is in the database, update it
end

function IADSSystem:findDetectedTargets()
    local allTargets = {}
    local antiRadiationMissiles = {}

    -- TODO: use a mockable interface to query DCS to support unit tests.

    -- Get all detected targets
    -- This will be called every 10 seconds
    -- If the target is not in the database, add it
    -- If the target is in the database, update it

    return allTargets, antiRadiationMissiles
end

-- @param target: Track
function IADSSystem:possiblyEngageWithSAMs(target)
    -- Engage with SAMs
    -- If the target is in a MEZ, engage with SAMs
    -- If the target is not in a MEZ, do not engage with SAMs
    -- Engage with SAMs
    -- Default to true in case we are not using any MEZs
    local shouldEngage = true

    if cfg.missileEngagementZones then
        -- We have MEZs defined
        -- Check if the target is in a MEZ
        -- If not, shouldEngage = false
        for i, mez in ipairs(missileEngagementZones) do
            if mez:contains(target.position) then
                local shooters = mez:shooters()
                for j, shooter in ipairs(shooters) do
                    shooter:engage(target)
                end
            end
        end
    end

    if shouldEngage then
        self:activateNearbySAMs(target)
    end
end

function IADSSystem:defendSAMSites()
    -- Calcuate incoming ARMs vs emitters
end

function IADSSystem:garbageCollect()
    -- Remove tracks older than a given time period
end

function IADSSystem:run()
    local allTargets, antiRadiationMissiles = self:findDetectedTargets()
    self:upsertTracks(allTargets, antiRadiationMissiles)
    -- Get targets and ARMs in MEZ and react
    self:defendSAMSites()
    for i, target in ipairs(allTargets) do
        self:possiblyEngageWithSAMs(target)
    end

    self:garbageCollect()
end

function RedFlagIADS.init()
    -- This will ensure the server does not pause on errors.
    -- Warning: you need to check your DCS logs if you do not have this variable set.
    if not __DEV_ENV == true then
        env.setErrorMessageBoxEnabled(false)
    end

    local system = IADSSystem:new(1, "RedFlagIADS")

    system.collectSensors()
    system.collectShooters()
    system.disableEmitters()

    -- TODO: set to sweep interval config param
    mist.scheduleFunction(system.run, nil, 0, 10)



    -- On the initial frame, the AWACS units have not registered themselves yet.
    -- Wait 1 second to give them time to initialize.
    -- Invoking addAWACSRadars on the first frame will result in an empty table.
    timer.scheduleFunction(system.addAWACSRadars, nil, timer.getTime() + 1)
end
