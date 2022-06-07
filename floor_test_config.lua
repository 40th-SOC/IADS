iads.config = {
    ["HELO_DETECTION_FLOOR"] = 200,
    ["FIXED_WING_DETECTION_FLOOR"] = 500,
    ["AIRSPACE_ZONE_POINTS"] = iads.util.borderFromGroupRoute("border"),
}

iads.init()