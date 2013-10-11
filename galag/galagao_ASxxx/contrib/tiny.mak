###########################################################################
#
#   tiny.mak
#
#   Small driver-specific example makefile
#	Use make SUBTARGET=tiny to build
#
#   Copyright Nicola Salmoria and the MAME Team.
#   Visit  http://mamedev.org for licensing and usage restrictions.
#
#   9/2013 (GN): tiny.mak file with galaga driver for MMAME 136.
#                Copy it to  MAME/src/mame
#                Build Mame .136 with tiny driver using the following:
#                   make emulator DEBUG=Y SYMBOLS=y SUBTARGET=tiny
#
###########################################################################

MAMESRC = $(SRC)/mame
MAMEOBJ = $(OBJ)/mame

AUDIO = $(MAMEOBJ)/audio
DRIVERS = $(MAMEOBJ)/drivers
LAYOUT = $(MAMEOBJ)/layout
MACHINE = $(MAMEOBJ)/machine
VIDEO = $(MAMEOBJ)/video

OBJDIRS += \
	$(AUDIO) \
	$(DRIVERS) \
	$(LAYOUT) \
	$(MACHINE) \
	$(VIDEO) \



#-------------------------------------------------
# Specify all the CPU cores necessary for the
# drivers referenced in tiny.c.
#-------------------------------------------------

CPUS += Z80
CPUS += M6502
CPUS += MCS48
CPUS += MCS51
CPUS += M6800
CPUS += M6809
CPUS += M680X0

CPUS += MB88XX


#-------------------------------------------------
# Specify all the sound cores necessary for the
# drivers referenced in tiny.c.
#-------------------------------------------------

SOUNDS += CUSTOM
SOUNDS += SAMPLES
SOUNDS += DAC
SOUNDS += DISCRETE
SOUNDS += AY8910
SOUNDS += YM2151
SOUNDS += ASTROCADE
SOUNDS += TMS5220
SOUNDS += OKIM6295
SOUNDS += HC55516
SOUNDS += YM3812
#system16
SOUNDS += UPD7759
SOUNDS += MSM5205
SOUNDS += YM3438
SOUNDS += RF5C68

SOUNDS += NAMCO
SOUNDS += DISCRETE



#-------------------------------------------------
# This is the list of files that are necessary
# for building all of the drivers referenced
# in tiny.c
#-------------------------------------------------

DRVLIBS = \
	$(MAMEOBJ)/tiny.o \
	$(MACHINE)/ticket.o \
	$(DRIVERS)/carpolo.o $(MACHINE)/carpolo.o $(VIDEO)/carpolo.o \
	$(DRIVERS)/circus.o $(AUDIO)/circus.o $(VIDEO)/circus.o \
	$(DRIVERS)/exidy.o $(AUDIO)/exidy.o $(VIDEO)/exidy.o \
	$(DRIVERS)/starfire.o $(VIDEO)/starfire.o \
	$(DRIVERS)/victory.o $(VIDEO)/victory.o \
	$(AUDIO)/targ.o \
	$(DRIVERS)/astrocde.o $(VIDEO)/astrocde.o \
	$(DRIVERS)/gridlee.o $(AUDIO)/gridlee.o $(VIDEO)/gridlee.o \
	$(DRIVERS)/williams.o $(MACHINE)/williams.o $(AUDIO)/williams.o $(VIDEO)/williams.o \
	$(AUDIO)/gorf.o \
	$(AUDIO)/wow.o \
	$(DRIVERS)/gaelco.o $(VIDEO)/gaelco.o $(MACHINE)/gaelcrpt.o \
	$(DRIVERS)/wrally.o $(MACHINE)/wrally.o $(VIDEO)/wrally.o \
    $(DRIVERS)/diverboy.o \
    $(DRIVERS)/system16.o $(VIDEO)/system16.o $(MACHINE)/system16.o $(VIDEO)/segaic16.o \
    $(AUDIO)/namco52.o $(AUDIO)/namco54.o $(AUDIO)/galaga.o \
    $(MACHINE)/namco06.o $(MACHINE)/namco50.o $(MACHINE)/namco51.o $(MACHINE)/namco53.o \
    $(MACHINE)/atari_vg.o $(MACHINE)/namcoio.o $(MACHINE)/xevious.o \
    $(VIDEO)/bosco.o $(VIDEO)/galaga.o $(VIDEO)/digdug.o $(VIDEO)/xevious.o \
    $(DRIVERS)/galaga.o 




#-------------------------------------------------
# layout dependencies
#-------------------------------------------------

$(DRIVERS)/astrocde.o:	$(LAYOUT)/gorf.lh \
						$(LAYOUT)/tenpindx.lh
$(DRIVERS)/circus.o:	$(LAYOUT)/circus.lh \
						$(LAYOUT)/crash.lh
