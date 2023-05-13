iads.config = {
    ["MAX_INTERCEPTOR_GROUPS"] = 2,
    ["REINFORCEMENT_INTERVAL"] = 900,
    ["ENABLE_SAM_DEFENSE"] = true,
    ["AIRSPACE_ZONE_POINTS"] = iads.util.borderFromGroupRoute("iads_border"),
    ["MISSILE_ENGAGMENT_ZONES"] = {
        ["MEZ"] = iads.util.borderFromGroupRoute("iads_border"),
    },
    ["FIGHTER_ENGAGEMENT_ZONES"] = {
        ["FEZ"] = iads.util.borderFromGroupRoute("fez"),
    },
    ["FIGHTER_ENGAGMENT_ZONE"] = iads.util.borderFromGroupRoute("fez"),
    ["HELO_DETECTION_FLOOR"] = 1000,
    ["RESPAWN_INTERCEPTORS"] = false,
    ["ENABLE_THREAT_MATCH"] = false,
    ["ENABLE_DEBUG_LOGGING"] = false,
    ["SAM_DEFENSE_TIMEOUT_RANGE"] = {200, 700},
    ["TACTICAL_SAM_WHITELIST"] = {
        ["SNR_75V"] = true,                --SA2
        ["Kub 1S91 str"] = true,           --SA6
        ["snr s-125 tr"] = true,           --SA3
        ["SA-11 Buk LN 9A310M1"] = true,   --SA11
        ["Hawk tr"] = true,                --Hawk
        ["Osa 9A33 ln"] = true,            --enable SA8
    },
}

iads.init()