iads.config = {
    ["FIGHTER_ENGAGEMENT_ZONES"] = {
		["Northern AO"] = iads.util.borderFromGroupRoute("northern_ao"),
        ["Southern AO"] = iads.util.borderFromGroupRoute("southern_ao"),
	},
	["MISSILE_ENGAGMENT_ZONES"] = {
		["Northern AO"] = iads.util.borderFromGroupRoute("northern_ao"),
        ["Southern AO"] = iads.util.borderFromGroupRoute("southern_ao"),
	}
}

iads.init()