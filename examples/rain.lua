iads.config = {
    ["MAX_INTERCEPTOR_GROUPS"] = 0,
    ["ENABLE_SAM_DEFENSE"] = true,
    ["HELO_DETECTION_FLOOR"] = 1000,
    ["RESPAWN_INTERCEPTORS"] = false,
    ["ENABLE_THREAT_MATCH"] = false,
    ["ENABLE_DEBUG_LOGGING"] = false,
    ["SAM_DEFENSE_TIMEOUT_RANGE"] = {60, 180},
    ["SAM_SUPPRESSION_EXEMPT_RADARS"] = {
        ["S-300PS 64H6E sr"] = false,	--SA-10 Search Radar
        ["S-300PS 40B6MD sr"] = false,	--SA-10 Search Radar
        ["S-300PS 40B6M tr"] = false,    --SA-10 Track Radar
    },
}

iads.init()