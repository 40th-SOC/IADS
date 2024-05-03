iads.config = {
    ["MAX_INTERCEPTOR_GROUPS"] = 0,
    ["REINFORCEMENT_INTERVAL"] = 900,
    ["ENABLE_SAM_DEFENSE"] = true,
    ["AIRSPACE_ZONE_POINTS"] = iads.util.borderFromGroupRoute("iads_border"),
    ["RESPAWN_INTERCEPTORS"] = false,
    ["ENABLE_THREAT_MATCH"] = false,
    ["ENABLE_DEBUG_LOGGING"] = true,
    ["SAM_DEFENSE_TIMEOUT_RANGE"] = {90, 180},
    ["TACTICAL_SAM_WHITELIST"] = {
        ["SNR_75V"] = true,                --SA2
        ["Kub 1S91 str"] = true,           --SA6
        ["snr s-125 tr"] = true,           --SA3
        ["SA-11 Buk LN 9A310M1"] = true,   --SA11,
        ["Hawk tr"] = true,                --Hawk
        ["RLS_19J6"] = true,             --SA-5 SR,
        ["S-300PS 64H6E sr"] = true,	--SA-10 Search Radar
        ["S-300PS 40B6MD sr"] = true,	--SA-10 Search Radar
    },
    ["SAM_SUPPRESSION_EXEMPT_RADARS"] = {
        ["S-300PS 64H6E sr"] = false,	--SA-10 Search Radar
        ["S-300PS 40B6MD sr"] = false,	--SA-10 Search Radar
        ["S-300PS 40B6M tr"] = false,    --SA-10 Track Radar
        ["55G6 EWR"] = true,			--Early Warning Radar
        ["1L13 EWR"] = true,			--Early Warning Radar
    },
    ["IGNORE_SAM_GROUPS"] = {
        ["Buk Convoy 1"] = true,
        ["Buk Convoy 2"] = true,
    },
}

iads.init()
