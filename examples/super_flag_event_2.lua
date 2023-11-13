iads.config = {
    ["MAX_INTERCEPTOR_GROUPS"] = 0
    ["REINFORCEMENT_INTERVAL"] = 900,
    ["ENABLE_SAM_DEFENSE"] = true,
    ["HELO_DETECTION_FLOOR"] = 1000,
    ["RESPAWN_INTERCEPTORS"] = false,
    ["ENABLE_THREAT_MATCH"] = false,
    ["ENABLE_DEBUG_LOGGING"] = false,
    ["SAM_DEFENSE_TIMEOUT_RANGE"] = {200, 700},
    ["AIRSPACE_ZONE_POINTS"] = iads.util.borderFromGroupRoute("iads_border"),
}

iads.init()