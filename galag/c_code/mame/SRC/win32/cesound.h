/***************************************************************************

    M.A.M.E.CE  -  Multiple Arcade Machine Emulator for WinCE
    Win32 Portions Copyright (C) 1997-98 Michael Soderstrom and Chris Kirmse
	WinCE Portions Copyright (C) 1999 Benjamin Cooley
    
    This file is part of MAMECE, and may only be used, modified and
    distributed under the terms of the MAME license, in "readme.txt".
    By continuing to use, modify or distribute this file you indicate
    that you have read the license and understand and accept it fully.

 ***************************************************************************/

/*
  09/2000, Glenn Neidermeier: modified for PocketPC/iPAQ
*/

#ifndef __CESOUND_H__
#define __CESOUND_H__

//#include "mixer.h" //typedef signed short INT16; // GN: in win32ce/sound/mixer.h

int     CESound_init(void);
void    CESound_exit(void);
int     CESound_start_audio_stream(int stereo);
void    CESound_stop_audio_stream(void);
int     CESound_update_audio_stream(INT16* buffer);

#endif
