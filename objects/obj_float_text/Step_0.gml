y += vy;
vy *= 0.95;
life--;
if (life <= 0) instance_destroy();
