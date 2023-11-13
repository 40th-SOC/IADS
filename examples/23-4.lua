iads.config = {
    ["MAX_INTERCEPTOR_GROUPS"] = nil,
    ["MAX_INTERCEPTOR_GROUPS_FLAG"] = "iads_max_interceptor_groups",
    ["REINFORCEMENT_INTERVAL"] = 900,
    ["ENABLE_SAM_DEFENSE"] = true,
    ["MISSILE_ENGAGMENT_ZONES"] = {
        ["MEZ"] = iads.util.borderFromGroupRoute("mez"),
    },
    ["FIGHTER_ENGAGEMENT_ZONES"] = {
        ["FEZ North"] = iads.util.borderFromGroupRoute("fez_north"),
        ["FEZ East"] = iads.util.borderFromGroupRoute("fez_east"),
    },
    ["RESPAWN_INTERCEPTORS"] = false,
    ["ENABLE_THREAT_MATCH"] = false,
    ["ENABLE_DEBUG_LOGGING"] = false,
    ["SAM_DEFENSE_TIMEOUT_RANGE"] = {200, 700},
    ["TACTICAL_SAM_WHITELIST"] = {
        ["SNR_75V"] = true,                --SA2
        ["Kub 1S91 str"] = true,           --SA6
        ["snr s-125 tr"] = true,           --SA3
        ["SA-11 Buk LN 9A310M1"] = true,   --SA11
        ["RLS_19J6"] = true,             --SA-5 SR
    },
}

iads.init()