/***************************************************************************

    M.A.M.E.CE  -  Multiple Arcade Machine Emulator for WinCE
    Win32 Portions Copyright (C) 1997-98 Michael Soderstrom and Chris Kirmse
	WinCE Portions Copyright (C) 1999,2000 Benjamin Cooley
    
    This file is part of MAMECE, and may only be used, modified and
    distributed under the terms of the MAME license, in "readme.txt".
    By continuing to use, modify or distribute this file you indicate
    that you have read the license and understand and accept it fully.

 ***************************************************************************/

//  8/2000 (Glenn Neidermeier): 
//   modified for iPAQ/PocketPC.
//  10/2012 (Glenn Neidermeier): 
//   cleanup.

/***************************************************************************

  CESound.c

 ***************************************************************************/
#include <windows.h>

#include "mame.h"
#include "driver.h"
#include "mixer.h"


int g_Samplerate; // GN: substitutes for Machine->sample_rate.


/***************************************************************************
    function prototypes
 ***************************************************************************/

/*static*/ int      CESound_init(void);
/*static*/ void     CESound_exit(void);

/*static*/ int      CESound_start_audio_stream(int stereo);
/*static*/ int      CESound_update_audio_stream(INT16* buffer);
/*static*/ void     CESound_stop_audio_stream(void);

static void     CESound_set_mastervolume(int volume);
static int      CESound_get_mastervolume(void);
static void     CESound_sound_enable(int enable);
static void     CESound_update_audio(void);

#if USED
static void     CESound_play_sample(int channel, signed char* data, int len, int freq, int volume, int loop);
static void     CESound_play_sample_16(int channel, signed short* data, int len, int freq, int volume, int loop);
static void     CESound_play_streamed_sample(int channel, signed char* data, int len, int freq, int volume, int pan);
static void     CESound_play_streamed_sample_16(int channel, signed short* data, int len, int freq, int volume, int pan);
static void     CESound_set_sample_freq(int channel,int freq);
static void     CESound_set_sample_volume(int channel,int volume);
static void     CESound_stop_sample(int channel);
static void     CESound_restart_sample(int channel);
static int      CESound_get_sample_status(int channel);
#endif


/***************************************************************************
    External variables
 ***************************************************************************/
/*
struct OSDSound CESound = 
{
    { CESound_init },                     //    int     (*init)(options_type *options);
    { CESound_exit },                     //    void    (*exit)(void);
    { CESound_start_audio_stream },       //    int     (*start_audio_stream)(int stereo);
    { CESound_update_audio_stream },      //    int     (*update_audio_stream)(INT16* buffer);
    { CESound_stop_audio_stream },        //    void    (*stop_audio_stream)(void);
    { CESound_set_mastervolume },         //    void    (*set_mastervolume)(int attenuation);
    { CESound_get_mastervolume },         //    int     (*get_mastervolume)(void);
    { CESound_sound_enable },             //    void    (*sound_enable)(int enable);
    { CESound_update_audio }              //    void    (*update_audio)(void);
};
*/
/***************************************************************************
    Internal structures
 ***************************************************************************/

#define NUM_WAVEHDRS  16 // GN:
#define FPS           60

struct tSound_private
{
    WAVEOUTCAPS m_Caps;
    HWAVEOUT m_hWaveOut;
    WAVEHDR m_WaveHdrs[NUM_WAVEHDRS];

    int m_nVolume; // -32 to 0 attenuation value
    int m_nChannels;
    int m_nSampleRate;
    int m_nSampleBits;

    int m_nSamplesPerFrame;
    int m_nBytesPerFrame;
};

/***************************************************************************
    Internal variables
 ***************************************************************************/

static struct tSound_private      This;

/***************************************************************************
    External OSD functions  
 ***************************************************************************/

/* static */ int CESound_init(void)
{

	UINT numdevs;

	MMRESULT res;
	WAVEFORMATEX wf;

	g_Samplerate = 44100; // init this for console version

	This.m_hWaveOut = NULL;
/*
	if (Machine->sample_rate == 0)
	{
		Machine->sample_rate = options->sample_rate;
	}
*/
	This.m_nSampleRate = g_Samplerate; // SAMPLE_RATE; // Machine->sample_rate;

	This.m_nSampleBits = 16;
	This.m_nChannels = 1;

	wf.wFormatTag = WAVE_FORMAT_PCM;
	wf.nChannels = This.m_nChannels; 
	wf.nSamplesPerSec = This.m_nSampleRate; 
	wf.nBlockAlign = This.m_nSampleBits * This.m_nChannels / 8;
	wf.nAvgBytesPerSec = This.m_nSampleRate * This.m_nSampleBits / 8; 
	wf.wBitsPerSample = This.m_nSampleBits; 
	wf.cbSize = 0;

	res = waveOutOpen(
		&This.m_hWaveOut,	// Handle
		WAVE_MAPPER, 		// ID (0 for wave mapper)
		&wf,			// Wave format
		0,			// Callback
		0,			// Instance data
		CALLBACK_NULL);

	if (res != MMSYSERR_NOERROR)
		return 1;

	memset(&This.m_WaveHdrs, 0, sizeof(WAVEHDR) * NUM_WAVEHDRS); // set WaveHdrs Buffers to 0s

	This.m_nVolume = 0;

	waveOutGetDevCaps(WAVE_MAPPER, &This.m_Caps, sizeof(WAVEOUTCAPS) );
	numdevs = waveOutGetNumDevs();
	return 0;
}


////////////////////////////////////////////////
void CESound_exit(void)
{
	BOOL done;
	int i, ticks;

	ticks = GetTickCount();
	done = FALSE;
	while (!done && GetTickCount() - ticks < 500)
	{
		done = TRUE;
		for (i = 0; i < NUM_WAVEHDRS; i++)
		{
			if (This.m_WaveHdrs[i].dwFlags & WHDR_DONE)
			{
				// unprepare the header before freeing the data or there will be exceptions!				
				waveOutUnprepareHeader(This.m_hWaveOut, &This.m_WaveHdrs[i], sizeof(WAVEHDR));

				if (This.m_WaveHdrs[i].lpData)
					free( This.m_WaveHdrs[i].lpData );				

				This.m_WaveHdrs[i].lpData = NULL;
				This.m_WaveHdrs[i].dwBufferLength = 0;
				This.m_WaveHdrs[i].dwFlags = 0;
			}
			else if (This.m_WaveHdrs[i].dwFlags)
				done = FALSE;
		}
	}

	waveOutClose(This.m_hWaveOut);
}


//
DWORD m_add, m_end;
////////////////////////////////////////////////////
int CESound_start_audio_stream(int stereo)
{
    int i; // count the WAVEHDRS

    if (g_Samplerate == 0) // if (Machine->sample_rate == 0)
        return 0;

    if (stereo)
        stereo = 1; /* make sure it's either 0 or 1 */

    // determine the number of samples and bytes per frame //

    // GN:   This.m_nSamplesPerFrame = (double)Machine->sample_rate / Machine->drv->frames_per_second;
    This.m_nSamplesPerFrame = g_Samplerate / FPS; // SAMPLE_RATE / FPS;
    This.m_nBytesPerFrame = This.m_nSamplesPerFrame * sizeof (INT16) * (stereo + 1);


    // GN: set up the buffer on each wave header
    for (i = 0; i < NUM_WAVEHDRS; i++)
    {
        int buflen = This.m_nBytesPerFrame; // len
        {
            This.m_WaveHdrs[i].dwBufferLength = buflen;
            This.m_WaveHdrs[i].dwFlags = 0;
        }
    }

    m_add = (((DWORD) (This.m_nSampleRate << 15) / (DWORD) This.m_nSampleRate) << 1) + 3;
    m_end = This.m_nBytesPerFrame << 15; // GN: I think we were too large by a factor of 2 // This.m_nBytesPerFrame << 16;

    return This.m_nSamplesPerFrame;
}


////////////////////////////////////////////////////////
int CESound_update_audio_stream(INT16* buffer)
{
    int buflen = This.m_nBytesPerFrame; // 1470 (16bit samples)
    int freq = This.m_nSampleRate; // 44100


    int i = 0;
    short *s;
    short *d;

    DWORD pos;


    for (i = 0; i < NUM_WAVEHDRS; i++)
    {
        if (This.m_WaveHdrs[i].dwFlags == 0 || This.m_WaveHdrs[i].dwFlags & WHDR_DONE)
        {
            //	newlen = oldlen * rate / freq;
            // check if this WAVE_HDR has had the lpData free'd before reusing....
            if (This.m_WaveHdrs[i].lpData /* && This.m_WaveHdrs[i].dwBufferLength != buflen */)
            {
                // unprepare the header before freeing the data or there will be exceptions!
                waveOutUnprepareHeader(This.m_hWaveOut, &This.m_WaveHdrs[i], sizeof (WAVEHDR));
                free(This.m_WaveHdrs[i].lpData);
                This.m_WaveHdrs[i].lpData = NULL;
            }

            // check if not WHDR_PREPARED before unpreparing?
            //			waveOutUnprepareHeader(This.m_hWaveOut, &This.m_WaveHdrs[i], sizeof(WAVEHDR));

            // reuse this WAVE_HDR 
            if (!This.m_WaveHdrs[i].lpData)
            {
                This.m_WaveHdrs[i].lpData = (LPSTR) malloc(buflen /* << 1 */);
                //				This.m_WaveHdrs[i].dwBufferLength = buflen;
                This.m_WaveHdrs[i].dwFlags = 0;

                waveOutPrepareHeader(This.m_hWaveOut, &This.m_WaveHdrs[i], sizeof (WAVEHDR));
            }


            s = buffer;
            d = (short *) This.m_WaveHdrs[i].lpData;

            //			add = (((DWORD)(freq << 15) / (DWORD)freq) << 1) + 3;
            //			end = buflen << 15; // buflen << 16;


            //  96337920 / 65539 = writing 1469 words
            // but my buffer len in bytes was 1470
            // so I am writing out twice as many bytes as necessary
            // note above malloc was also mallocing twice as long a buffer as needed.
            //			for (pos = 0; pos < end; pos += add) 
            for (pos = 0; pos < m_end; pos += m_add)
            {
                *d++ = s[pos >> 16];
            }

            waveOutWrite(This.m_hWaveOut, &This.m_WaveHdrs[i], sizeof (WAVEHDR));
            return This.m_nSamplesPerFrame;
        }
    }
    return 0; // GN: doesn't really return here usually
}


//////////////////////////////////////////////////
void    CESound_stop_audio_stream(void)
{
	;
}


/////////////////////////////////////////////////
static void CESound_set_mastervolume(int volume)
{
	This.m_nVolume = volume;
}


/////////////////////////////////////////////////
static int CESound_get_mastervolume(void)
{
    return This.m_nVolume;
}

/////////////////////////////////////////////////
static void CESound_sound_enable(int enable)
{
	;
}

/////////////////////////////////////////////////
static void CESound_update_audio(void)
{
	;
}




#if USED
/////////////////////////////////////////////////
void CESound_play_sample(int channel, signed char *data, int len, int freq, int volume, int loop)
{
	int i;
	signed char *s; // GN // signed short *s;
	signed char *d; // GN: test // short *d;
	DWORD pos, add, end;

	int tmp = 0; // GN: test


	for (i = 0; i < NUM_WAVEHDRS; i++)
	{
		if (This.m_WaveHdrs[i].dwFlags == 0 || This.m_WaveHdrs[i].dwFlags & WHDR_DONE)
		{
			DWORD newlen = len * This.m_nSampleRate;
			newlen /= freq;
			if (This.m_WaveHdrs[i].lpData && This.m_WaveHdrs[i].dwBufferLength != newlen)
			{
				waveOutUnprepareHeader(This.m_hWaveOut, &This.m_WaveHdrs[i], sizeof(WAVEHDR));
				free(This.m_WaveHdrs[i].lpData);
				This.m_WaveHdrs[i].lpData = NULL;
			}
			if (!This.m_WaveHdrs[i].lpData)
			{
				This.m_WaveHdrs[i].lpData = (LPSTR)malloc(newlen << 1);
				This.m_WaveHdrs[i].dwBufferLength = newlen;
				This.m_WaveHdrs[i].dwFlags = 0;
				waveOutPrepareHeader(This.m_hWaveOut, &This.m_WaveHdrs[i], sizeof(WAVEHDR));
			}

			s = data;
			d = (signed short *)This.m_WaveHdrs[i].lpData;

			add = (( (DWORD)(freq << 15) / (DWORD)This.m_nSampleRate) << 1) + 3;

			add = freq << 15; // frequency of the sample (scaled by 32768, 15-bit shift)
			add = add / This.m_nSampleRate; 

//			add <<= 1;
//			add += 3;

			end = len << 15;

			for (pos = 0; pos < end; pos += add)
			{
				int loc = pos >> 15; // (it was scaled by 15 bit shift)
				tmp++;

				// Undersample: write out as 16 bit (with high byte 0) 
				// (if you set "add" to read every other byte)
//				*d++ = (unsigned char)((int)s[ loc ] + 128); 
				// Just read/write at normal rate
				*d++ = s[ loc ] + 128;
			}

			waveOutWrite(This.m_hWaveOut, &This.m_WaveHdrs[i], sizeof(WAVEHDR));
			return;	
		}
	}

}

/////////////////////////////////////////////////
static void CESound_play_sample_16(int channel, signed short *data, int len, int freq, int volume, int loop)
{
	int i;
	signed short *s;
	signed short *d;
	DWORD pos, add, end;

	for (i = 0; i < NUM_WAVEHDRS; i++)
	{
		if (This.m_WaveHdrs[i].dwFlags == 0 || This.m_WaveHdrs[i].dwFlags & WHDR_DONE)
		{
			int newlen = len * This.m_nSampleRate / freq;
			if (This.m_WaveHdrs[i].lpData && This.m_WaveHdrs[i].dwBufferLength != newlen)
			{
				waveOutUnprepareHeader(This.m_hWaveOut, &This.m_WaveHdrs[i], sizeof(WAVEHDR));
				free(This.m_WaveHdrs[i].lpData);
				This.m_WaveHdrs[i].lpData = NULL;
			}
			if (!This.m_WaveHdrs[i].lpData)
			{
				This.m_WaveHdrs[i].lpData = (LPSTR)malloc(newlen << 1);
				This.m_WaveHdrs[i].dwBufferLength = newlen;
				This.m_WaveHdrs[i].dwFlags = 0;
				waveOutPrepareHeader(This.m_hWaveOut, &This.m_WaveHdrs[i], sizeof(WAVEHDR));
			}
			s = data;
			d = (signed short *)This.m_WaveHdrs[i].lpData;
			add = (((DWORD)(freq << 15) / (DWORD)This.m_nSampleRate) << 1) + 3;
			end = len << 16;
			for (pos = 0; pos < end; pos += add)
				*d++ = (signed char)s[(pos >> 16)];
			waveOutWrite(This.m_hWaveOut, &This.m_WaveHdrs[i], sizeof(WAVEHDR));
			return;	
		}
	}
}

/////////////////////////////////////////////////
static void CESound_play_streamed_sample(int channel, signed char *data, int len, int freq, int volume, int pan)
{
	int i;
	signed char *s;
	unsigned char *d;
	DWORD pos, add, end;
	int rate;

	rate = This.m_nSampleRate * 100 / 75;

	for (i = 0; i < NUM_WAVEHDRS; i++)
	{
		if (This.m_WaveHdrs[i].dwFlags == 0 || This.m_WaveHdrs[i].dwFlags & WHDR_DONE)
		{
			int newlen = len * rate / freq;
			if (This.m_WaveHdrs[i].lpData && This.m_WaveHdrs[i].dwBufferLength != newlen)
			{
				waveOutUnprepareHeader(This.m_hWaveOut, &This.m_WaveHdrs[i], sizeof(WAVEHDR));
				free(This.m_WaveHdrs[i].lpData);
				This.m_WaveHdrs[i].lpData = NULL;
			}
			if (!This.m_WaveHdrs[i].lpData)
			{
				This.m_WaveHdrs[i].lpData = (LPSTR)malloc(newlen);
				This.m_WaveHdrs[i].dwBufferLength = newlen;
				This.m_WaveHdrs[i].dwFlags = 0;
				waveOutPrepareHeader(This.m_hWaveOut, &This.m_WaveHdrs[i], sizeof(WAVEHDR));
			}
			s = data;
			d = (unsigned char *)This.m_WaveHdrs[i].lpData;
			add = (((DWORD)(freq << 15) / (DWORD)rate) << 1) + 3;
			end = len << 16;
			for (pos = 0; pos < end; pos += add)
				*d++ = (unsigned char)((int)s[(pos >> 16)] + 128);
			waveOutWrite(This.m_hWaveOut, &This.m_WaveHdrs[i], sizeof(WAVEHDR));
			return;	
		}
	}
}

/////////////////////////////////////////////////
static void CESound_play_streamed_sample_16(int channel, signed short *data, int len, int freq, int volume, int pan)
{
	int i;
	signed short *s;
	signed short *d;
	DWORD pos, add, end;
	int rate;

	rate = This.m_nSampleRate * 100 / 75;

	for (i = 0; i < NUM_WAVEHDRS; i++)
	{
		if (This.m_WaveHdrs[i].dwFlags == 0 || This.m_WaveHdrs[i].dwFlags & WHDR_DONE)
		{
			int newlen = len * rate / freq;
			if (This.m_WaveHdrs[i].lpData && This.m_WaveHdrs[i].dwBufferLength != newlen)
			{
				waveOutUnprepareHeader(This.m_hWaveOut, &This.m_WaveHdrs[i], sizeof(WAVEHDR));
				free(This.m_WaveHdrs[i].lpData);
				This.m_WaveHdrs[i].lpData = NULL;
			}
			if (!This.m_WaveHdrs[i].lpData)
			{
				This.m_WaveHdrs[i].lpData = (LPSTR)malloc(newlen << 1);
				This.m_WaveHdrs[i].dwBufferLength = newlen;
				This.m_WaveHdrs[i].dwFlags = 0;
				waveOutPrepareHeader(This.m_hWaveOut, &This.m_WaveHdrs[i], sizeof(WAVEHDR));
			}
			s = data;
			d = (signed short *)This.m_WaveHdrs[i].lpData;
			add = (((DWORD)(freq << 15) / (DWORD)rate) << 1) + 3;
			end = len << 16;
			for (pos = 0; pos < end; pos += add)
				*d++ = (signed char)s[(pos >> 16)];
			waveOutWrite(This.m_hWaveOut, &This.m_WaveHdrs[i], sizeof(WAVEHDR));
			return;	
		}
	}
}

/////////////////////////////////////////////////
static void CESound_set_sample_freq(int channel,int freq)
{
}

/////////////////////////////////////////////////
static void CESound_set_sample_volume(int channel,int volume)
{
}

/////////////////////////////////////////////////
static void CESound_stop_sample(int channel)
{
}

/////////////////////////////////////////////////
static void CESound_restart_sample(int channel)
{
}

/////////////////////////////////////////////////
static int CESound_get_sample_status(int channel)
{
    return 0;
}

#endif
