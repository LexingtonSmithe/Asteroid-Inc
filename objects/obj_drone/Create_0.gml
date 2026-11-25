/// Guard drone: orbits the station and rams asteroids that cross its path.
/// Each collision costs it one hit; at zero it's knocked out and rebuilds after a delay.
/// The station sets orbit_angle when it creates the drones.
depth = -15;
image_speed = 0;          // frame 0 = outline, frame 1 = fill (drawn by remaining hits)
orbit_angle = 0;
orbit_radius = STATION_RADIUS + 70;
orbit_speed = 1.2;        // degrees per frame
max_hits = global.stats.drone_hits;
hits = max_hits;
rebuild = 0;              // frames until it's back online (0 = online)
hit_cd = 0;               // brief immunity after a collision so one rock = one hit
flash = 0;
x = STATION_X + lengthdir_x(orbit_radius, orbit_angle);
y = STATION_Y + lengthdir_y(orbit_radius, orbit_angle);
