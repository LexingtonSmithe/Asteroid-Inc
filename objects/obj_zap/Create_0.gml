/// Chain-lightning bolt visual. points = [[x, y], ...] set by the station.
/// Purely visual: damage is applied when it's created.
depth = -12;
points = [];
path = undefined; // jagged bolt, built on the first draw (Draw_0)
life = 12;
width = 7; // px (the ion storm draws a thicker one)
life_max = life;
