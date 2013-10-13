#ifndef SAMPLES_H
#define SAMPLES_H

struct Samplesinterface
{
	int channels;	/* number of discrete audio channels needed */
	int volume;		/* global volume for all samples */
	const char **samplenames;
};


/* Start one of the samples loaded from disk. Note: channel must be in the range */
/* 0 .. Samplesinterface->channels-1. It is NOT the discrete channel to pass to */
/* mixer_play_sample() */
void sample_start(int channel,int samplenum,int loop);
void sample_set_freq(int channel,int freq);
void sample_set_volume(int channel,int volume);
void sample_stop(int channel);
int sample_playing(int channel);

// GN: change this interface for Mame27ce
//int samples_sh_start(const struct MachineSound *msound);
int samples_sh_start( void );

// GN: new interface added for Mame27ce
void sample_start2(int channel,unsigned char *data,int len,int freq,int volume,int loop);

#endif
