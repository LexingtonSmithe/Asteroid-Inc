/// Rail gun slug: very fast, pierces everything in its path, drawn as a streak of light.
/// The station sets dir, damage and width (hit radius either side of the path).
depth = -6;
dir = 0;
damage = 400;
width = 10;
spd = 48;
intensity = 1;     // scales damage and trail alpha; drops with every rock pierced
falloff = RAIL_FALLOFF; // share of intensity lost per rock (set by the station from Rail Calibre)
hit = [];          // asteroids already struck by this slug
trail = [];        // recent positions for the streak
