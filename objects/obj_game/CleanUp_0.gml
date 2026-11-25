fx_cleanup();
if (view_camera[0] != -1) camera_destroy(view_camera[0]);
global.view_zoom = 1; // other rooms draw unzoomed
