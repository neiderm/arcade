# ROM0 sub-makefile
S19= ga0.i86

# Note that ld adds code to a given section as it loads each file, so the order
# in which items are added to OBJS is important in order to keep the original 
# ROM placement ... if an area happens to span multiple modules e.g. CSEG00.

OBJS= \
      mrw.rel \
      int.rel \
      task_man.rel \
      game_ctrl.rel \
      gg1-2.rel \
      gg1-2_fx.rel \
      gg1-3.rel \
      new_stage.rel \
      gg1-4.rel \
      gg1-5.rel \
      gg1-7.rel

# Set linker arguments for code segment locations which are specific to the CPU
# address space. 
CSEGDEF= \
  -b CSEG00=0x0096 -b CSEG10=0x1000 -b CSEG17=0x1700 \
  -b CSEG20=0x2000 -b CSEG2C=0x2C00 -b CSEG30=0x3000 



RM=rm -f


ASXDIR=/usr/local/bin


#  -g   Undefined symbols made global
#  -l   Create list output (out)file[.lst]
#  -p   Disable listing pagination
#  -a   All user symbols made global
ASFLAGS=-l -p -a


#  -m   Map output generated as (out)file[.map]
#  -w   Wide listing format for map file
#  -i   Intel Hex as (out)file[.i--]
# Use (+=) so that cpu "makefile"s can set specific segment locations.
LDFLAGS= -i -m -w

# RAM segments are common to all CPUs.
LDFLAGS+=  -b RAM0=0x8800 -b RAM1=0x9000 -b RAM2=0x9800

AS= $(ASXDIR)/asez80
LD= $(ASXDIR)/aslink $(LDFLAGS)


# TODO: doesn' work right.
# Probably need to make  inc's shared between all CPUs
HEADERS= $(wildcard rom0/*.inc)


# Code segment addresses are set by the include'ing makefile and the linker 
LDFLAGS+= $(CSEGDEF)


# here come the rules .... 

all: $(S19)


# Auto-generated includes must be made dependent upon source files.
# We use asm "-a" option and export all global symbols in code space.
# Data space globals are defined in common "mrw.S" file in parent directory but
# external functions and data in code space are specific to each ROM module.
incs: mrw.s $(wildcard *.s)
	echo ";.include "\"..\/sfrs.inc\" > exvars.inc 
	cat $< | sed -r -n '/^[_a-zA-Z0-9]+:/p' | sed 's/:.*// ; s/^/.globl /' | sort -u >> exvars.inc
	cat *.s | sed -r -n '/^[_a-zA-Z0-9]+:/p' | sed 's/:.*// ; s/^/.globl /' | sort -u > exfuncs.inc


$(S19): $(OBJS)
	@-echo "Linking bin object: $*"
	$(LD) $@ $(OBJS)


%.rel: %.s $(HEADERS) incs
	@-echo "Making component: $*"
	$(AS) $(ASFLAGS) -o $<


clean:
	$(RM) *.rel *.s19 *.lst *.map *.noi *.lk *.ihx *.sym *.asm *.i86


