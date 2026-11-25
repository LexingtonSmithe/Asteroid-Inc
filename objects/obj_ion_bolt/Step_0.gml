if (world_paused()) exit;
warn--;
if (warn <= 0) {
    strike();
    instance_destroy();
}
