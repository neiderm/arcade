// samples.c
/*
  8/2000, 10/2012 (Glenn Neidermeier): this file is from Mame V36 and
   has been slightly modified to integrate with Mame21. Primarily, the
   global variable "g_Samplerate" substitutes for Machine->sample_rate.
*/
#include "mame.h" // error_log

#include "mixer.h" // GN

#include "driver.h"


extern int g_Samplerate; // GN


static int firstchannel,numchannels;




#if 0 // Machine->samples doesn't exist in early versions

/* Start one of the samples loaded from disk. Note: channel must be in the range */
/* 0 .. Samplesinterface->channels-1. It is NOT the discrete channel to pass to */
/* mixer_play_sample() */
void sample_start(int channel,int samplenum,int loop)
{
	if (Machine->sample_rate == 0) return;
	if (Machine->samples == 0) return;
	if (Machine->samples->sample[samplenum] == 0) return;
	if (channel >= numchannels)
	{
		if (errorlog) fprintf(errorlog,"error: sample_start() called with channel = %d, but only %d channels allocated\n",channel,numchannels);
		return;
	}
	if (samplenum >= Machine->samples->total)
	{
		if (errorlog) fprintf(errorlog,"error: sample_start() called with samplenum = %d, but only %d samples available\n",samplenum,Machine->samples->total);
		return;
	}

	if ( Machine->samples->sample[samplenum]->resolution == 8 )
	{
		if (errorlog) fprintf(errorlog,"play 8 bit sample %d, channel %d\n",samplenum,channel);
		mixer_play_sample(firstchannel + channel,
				Machine->samples->sample[samplenum]->data,
				Machine->samples->sample[samplenum]->length,
				Machine->samples->sample[samplenum]->smpfreq,
				loop);
	}
	else
	{
		if (errorlog) fprintf(errorlog,"play 16 bit sample %d, channel %d\n",samplenum,channel);
		mixer_play_sample_16(firstchannel + channel,
				(short *) Machine->samples->sample[samplenum]->data,
				Machine->samples->sample[samplenum]->length,
				Machine->samples->sample[samplenum]->smpfreq,
				loop);
	}
}
#else// GN: modified interface for sample_start()
void sample_start2(int channel,unsigned char *data,int len,int freq,int volume,int loop)
{
	if (channel >= numchannels)
	{
		if (errorlog) fprintf(errorlog,"error: sample_start() called with channel = %d, but only %d channels allocated\n",channel,numchannels);
		return;
	}

	mixer_play_sample(firstchannel + channel,
				data,
				len,
				freq,
				loop);
}
#endif

void sample_set_freq(int channel,int freq)
{
// GN //	if (Machine->sample_rate == 0) return;
	if (g_Samplerate == 0) return;
//	if (Machine->samples == 0) return;
	if (channel >= numchannels)
	{
		if (errorlog) fprintf(errorlog,"error: sample_adjust() called with channel = %d, but only %d channels allocated\n",channel,numchannels);
		return;
	}

	mixer_set_sample_frequency(channel + firstchannel,freq);
}

void sample_set_volume(int channel,int volume)
{
// GN //	if (Machine->sample_rate == 0) return;
	if (g_Samplerate == 0) return;
//	if (Machine->samples == 0) return; // GN: this was not working for mspac, which does not have any "samples"
	if (channel >= numchannels)
	{
		if (errorlog) fprintf(errorlog,"error: sample_adjust() called with channel = %d, but only %d channels allocated\n",channel,numchannels);
		return;
	}

	mixer_set_volume(channel + firstchannel,volume * 100 / 255);
}

void sample_stop(int channel)
{
// GN //	if (Machine->sample_rate == 0) return;
	if (g_Samplerate == 0) return;
	if (channel >= numchannels)
	{
		if (errorlog) fprintf(errorlog,"error: sample_stop() called with channel = %d, but only %d channels allocated\n",channel,numchannels);
		return;
	}

	mixer_stop_sample(channel + firstchannel);
}

int sample_playing(int channel)
{
// GN //	if (Machine->sample_rate == 0) return 0;
	if (g_Samplerate == 0) return 0;
	if (channel >= numchannels)
	{
		if (errorlog) fprintf(errorlog,"error: sample_playing() called with channel = %d, but only %d channels allocated\n",channel,numchannels);
		return 0;
	}

	return mixer_is_sample_playing(channel + firstchannel);
}



#define NUMVOICES 8 // GN: the highest number that I know of, Galaga, plays a sample on channel 7

// GN // int samples_sh_start(const struct MachineSound *msound)
int samples_sh_start(void)
{
	int i;
	int vol[MIXER_MAX_CHANNELS];
// GN //	const struct Samplesinterface *intf = msound->sound_interface;

	/* read audio samples if available */
// GN //	Machine->samples = readsamples(intf->samplenames,Machine->gamedrv->name);

	numchannels = NUMVOICES; // 1; // GN // intf->channels;
	for (i = 0;i < numchannels;i++)
		vol[i] = 50; // GN // intf->volume;
	firstchannel = mixer_allocate_channels(numchannels,vol);
	for (i = 0;i < numchannels;i++)
	{
		char buf[40];

		sprintf(buf,"Sample #%d",i);
		mixer_set_name(firstchannel + i,buf);
	}
	return 0;
}
