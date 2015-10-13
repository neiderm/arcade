# ROM0 sub-makefile

# aslink generates "Intel I86 Output Format (24 or 32-Bit)" since I am using
# .BANK directive to separate CPU spaces. This causes a type 4 "segment record" 
# to be emitted into the .i86 file.
                        
I86= ga0.i86

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


RM=rm -f


ASXDIR=/usr/local/bin
AS= $(ASXDIR)/asez80
LD= $(ASXDIR)/aslink 

#  -g   Undefined symbols made global
#  -l   Create list output (out)file[.lst]
#  -w   Wide listing format for symbol table
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

# Set linker arguments for code segment locations which are specific to the CPU
# address space. 
CSEGDEF= \
  -b CSEG00=0x0096 -b CSEG10=0x1000 -b CSEG17=0x1700 \
  -b CSEG20=0x2000 -b CSEG2C=0x2C00 -b CSEG30=0x3000 

# Code segment addresses are set by the include'ing makefile and the linker 
LDFLAGS+= $(CSEGDEF)


# here come the rules .... 

all: $(I86)

# Auto-generated includes must be made dependent upon source files.
# We use asm "-a" option and export all global symbols in code space.
# Data space globals are defined in common "mrw.S" file in parent directory but
# external functions and data in code space are specific to each ROM module.
# A little help here:
# http://www.cprogramming.com/tutorial/makefiles_continued.html
#  $? macro stores the list of dependents more recent than the target
#  $^ gives you all dependencies, regardless of whether they are more recent than the target. 
#  $@ is the name of the target. 
#  $< when you have only a single dependency

# prevent make from deleting "interediate" .dep files
#  http://darrendev.blogspot.com/2008/06/stopping-make-delete-intermediate-files.html
.SECONDARY:

%.dep: %.s
	@-echo "Making dependency: $*"
	@-asez80 -l -w -p  $<  2>/dev/null
	@cat $(basename $<).lst | grep ' \*\*\*\*\*\* X' \
	| sed 's/^\ *// ; s/\ .*$$// ; s/^/.globl /' > $@


$(I86): $(OBJS)
	$(LD) $(LDFLAGS) $@ $^

%.rel: %.s %.dep $(wildcard *.inc)
	@-echo "Making component: $*"
	$(AS) $(ASFLAGS) -o $<

clean:
	$(RM) *\.rel *\.s19 *\.lst *\.map *\.i86 *\.hlr 
	$(RM) exfuncs.inc exvars.inc

distclean: clean
	@echo "distclean: clean"
	$(RM) *\.dep 
