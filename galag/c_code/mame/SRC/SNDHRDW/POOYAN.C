#include "driver.h"
#include "Z80.h"
#include "sndhrdw/generic.h"
#include "sndhrdw/8910intf.h"



static int pooyan_portB_r(int offset)
{
	int clockticks,clock;

#define TIMER_RATE (32)

	clockticks = (Z80_IPeriod - cpu_geticount());

	clock = clockticks / TIMER_RATE;

	return clock;
}



int pooyan_sh_interrupt(void)
{
	if (pending_commands) return 0xff;
	else return Z80_IGNORE_INT;
}



static struct AY8910interface interface =
{
	2,	/* 2 chips */
	1789750000,	/* 1.78975 MHZ ?? */
	{ 255, 255 },
	{ sound_command_r },
	{ pooyan_portB_r },
	{ },
	{ }
};



int pooyan_sh_start(void)
{
	pending_commands = 0;

	return AY8910_sh_start(&interface);
}
