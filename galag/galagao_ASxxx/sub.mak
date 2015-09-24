# This needs to go away: now that the asXXX .bank directive is successfully 
# used to unify all 3 CPUs into a single build.

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


# Auto-generated includes must be make dependent upon source files.
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

