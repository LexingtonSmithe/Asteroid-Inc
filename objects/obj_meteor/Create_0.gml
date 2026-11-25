/// Meteor (meteor shower day, scr_conditions). Tiny and fast, flies in a straight line.
/// Smashes into the first asteroid it meets (free loot, or a dangerous break-up) or hits
/// the station more lightly than a comet. Can't be shot. spawn_meteor sets the rest.
vx = 0;
vy = 0;
radius  = 4;
impact  = 1;    // station damage
dmg     = 1;    // asteroid damage
entered = false;
age     = 0;
trail   = [];
