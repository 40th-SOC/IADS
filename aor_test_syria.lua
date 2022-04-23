iads.config = {
    ["FIGHTER_ENGAGEMENT_ZONES"] = {
		["TurkeyFEZ"] = iads.util.borderFromGroupRoute("TurkeyFEZ"),
        ["CyprusFEZ"] = iads.util.borderFromGroupRoute("CyprusFEZ"),
	},
	-- ["MISSILE_ENGAGMENT_ZONES"] = {
	-- 	["Northern AO"] = iads.util.borderFromGroupRoute("northern_ao"),
    --     ["Southern AO"] = iads.util.borderFromGroupRoute("southern_ao"),
	-- }
}

iads.init()