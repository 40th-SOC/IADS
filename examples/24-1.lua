iads.config = {
    ["MAX_INTERCEPTOR_GROUPS"] = 0,
    ["REINFORCEMENT_INTERVAL"] = 900,
    ["ENABLE_SAM_DEFENSE"] = true,
    ["AIRSPACE_ZONE_POINTS"] = iads.util.borderFromGroupRoute("iads_border"),
    ["RESPAWN_INTERCEPTORS"] = false,
    ["ENABLE_THREAT_MATCH"] = false,
    ["ENABLE_DEBUG_LOGGING"] = true,
    ["SAM_DEFENSE_TIMEOUT_RANGE"] = {120, 240},
    ["TACTICAL_SAM_WHITELIST"] = {
        ["SNR_75V"] = true,                --SA2
        -- ["Kub 1S91 str"] = true,           --SA6
        ["snr s-125 tr"] = true,           --SA3
        ["SA-11 Buk LN 9A310M1"] = true,   --SA11,
        ["Hawk tr"] = true,                --Hawk
        ["RLS_19J6"] = true,             --SA-5 SR
    },
}

iads.init()
