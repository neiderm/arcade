diff --git a/src/cpuintrf.h b/src/cpuintrf.h
index 15687fc..e7c064b 100644
--- a/src/cpuintrf.h
+++ b/src/cpuintrf.h
@@ -565,7 +565,7 @@ void cpu_set_m68k_reset(int cpunum, void (*resetfn)(void));
 /* return a pointer to the interface struct for a given CPU type */
 INLINE const struct cpu_interface *cputype_get_interface(int cputype)
 {
-	extern const struct cpu_interface cpuintrf[];
+	extern struct cpu_interface cpuintrf[];
 	return &cpuintrf[cputype];
 }
 
diff --git a/src/mame.c b/src/mame.c
index aad4b3c..580c185 100644
--- a/src/mame.c
+++ b/src/mame.c
@@ -566,7 +566,11 @@ void run_machine_core(void)
 				}
 
 				/* run the emulation! */
+#ifdef SIM
+				sim_run();
+#else
 				cpu_run();
+#endif
 
 				/* save the NVRAM */
 				if (Machine->drv->nvram_handler)
@@ -1168,11 +1172,11 @@ void force_partial_update(int scanline)
 	/* if skipping this frame, bail */
 	if (osd_skip_this_frame())
 		return;
-
+#ifndef SIM
 	/* skip if less than the lowest so far */
 	if (scanline < last_partial_scanline)
 		return;
-
+#endif
 	/* if there's a dirty bitmap and we didn't do any partial updates yet, handle it now */
 	if (full_refresh_pending && last_partial_scanline == 0)
 	{
@@ -1187,7 +1191,14 @@ void force_partial_update(int scanline)
 		clip.max_y = scanline;
 
 	/* render if necessary */
+#ifdef SIM
+clip.min_y = 0;
+clip.max_y = 223;
+clip.min_x = 0;
+clip.max_x = 287;
+#else
 	if (clip.min_y <= clip.max_y)
+#endif
 	{
 		profiler_mark(PROFILER_VIDEO);
 #ifdef MESS
diff --git a/src/unix/video-drivers/x11_window.c b/src/unix/video-drivers/x11_window.c
index 481dd0f..dab2885 100644
--- a/src/unix/video-drivers/x11_window.c
+++ b/src/unix/video-drivers/x11_window.c
@@ -368,14 +368,14 @@ static int x11_find_best_visual(int bitmap_depth)
 {
    XVisualInfo visualinfo;
    int screen_no = DefaultScreen (display);
-
+#if 0 // GN: black regions become transparent on my test machines (VirtualBox xubuntu 14.04, MacAir xubuntu 14.04)
    if (XMatchVisualInfo (display, screen_no, 32, TrueColor, &visualinfo))
    {
       xvisual = visualinfo.visual;
       depth   = 32;
       return 0;
    }
-
+#endif
    if (XMatchVisualInfo (display, screen_no, 24, TrueColor, &visualinfo))
    {
       xvisual = visualinfo.visual;
diff --git a/src/vidhrdw/galaga.c b/src/vidhrdw/galaga.c
index 4bb0670..ec24d75 100644
--- a/src/vidhrdw/galaga.c
+++ b/src/vidhrdw/galaga.c
@@ -186,8 +186,9 @@ VIDEO_UPDATE( galaga )
 {
 	int offs;
 
-
+#ifndef SIM
 	if (get_vh_global_attribute_changed())
+#endif
 	{
 		memset(dirtybuffer,1,videoram_size);
 	}
