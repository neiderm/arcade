# Top-level Makefile.
#
# Running "make" builds the code, generates ROM files and runs mame ($MAMED).
#
# All binary file generation is done by srec_cat, which has lots of tricks...
# including the generation and placment of the proper checksum in each chip image!
#

# Select configuration, these are the two I use: 
#
ARCH := $(shell uname -s)

ifeq ($(ARCH), Linux)
 # MAME 0.79, *nix ... srec_cat, asxxxx, xmame binaries in /usr/local/bin
 MAMED= xmamed.x11
 MAMED= xmame.x11
 MAMEOPTS= -debug -skip_gameinfo -rompath .
 MAMEOPTS=  -skip_gameinfo -rompath .
# MAMEOPTS+= -window -nomaximize
 GAMENAME= galaga
else
 # MAME 0.136, Windows
 MAMED= /cygdrive/c/home/myjunk/mame0136/mamed.exe
 MAMEOPTS= -debug -skip_gameinfo -rompath .
 MAMEOPTS+= -window -nomaximize
 GAMENAME= galagao
endif

OBJC= srec_cat 
RM= rm -f

##############
# ROM Info

ROM0IHX= ga0.ihx
ROM1IHX= ga1.ihx
ROM2IHX= ga2.ihx

ROM0SIZE= 16384
ROM1SIZE= 4096
ROM2SIZE= 4096


OFDIR= ./$(GAMENAME)

ifeq ($(GAMENAME), galaga)
 # These are for xmame(0.36), xmame(0.79)
 R1_1= $(OFDIR)/04m_g01.bin
 R1_2= $(OFDIR)/04k_g02.bin
 R1_3= $(OFDIR)/04j_g03.bin
 R1_4= $(OFDIR)/04h_g04.bin
 R2_1= $(OFDIR)/04e_g05.bin
 R3_1= $(OFDIR)/04d_g06.bin
else
 # These are for xmame(0.136)
 R1_1= $(OFDIR)/gg1-1.3p
 R1_2= $(OFDIR)/gg1-2.3m
 R1_3= $(OFDIR)/gg1-3.2m
 R1_4= $(OFDIR)/gg1-4.2l
 R2_1= $(OFDIR)/gg1-5.3f
 R3_1= $(OFDIR)/gg1-7.2c
endif

ROMS= $(R1_1) $(R1_2) $(R1_3) $(R1_4) $(R2_1) $(R3_1)


all: test


SREC_ARGS= -intel -fill 0xff 0x0
SREC_CKSUM_LENEG= -checksum-neg-l-e
SREC_CKSUM_BTNOT= -checksum-bitnot-l-e

# note: negative sign on offsets is intentional.
# $< when you have only a single dependency
# $@ is the name of the target. 
#
# TODO: mkdir $(OFDIR) target
#
$(R1_1): $(ROM0IHX)
	$(OBJC) $< $(SREC_ARGS) $(ROM0SIZE) -crop 0x0000 0x0FFF  -offset -0x0000  $(SREC_CKSUM_LENEG) 0x0FFF 1 1  -o $@ -Binary
$(R1_2): $(ROM0IHX)
	$(OBJC) $< $(SREC_ARGS) $(ROM0SIZE) -crop 0x1000 0x1FFF  -offset -0x1000  $(SREC_CKSUM_LENEG) 0x0FFF 1 1  -o $@ -Binary
$(R1_3): $(ROM0IHX)
	$(OBJC) $< $(SREC_ARGS) $(ROM0SIZE) -crop 0x2000 0x2FFF  -offset -0x2000  $(SREC_CKSUM_LENEG) 0x0FFF 1 1  -o $@ -Binary
$(R1_4): $(ROM0IHX)
	$(OBJC) $< $(SREC_ARGS) $(ROM0SIZE) -crop 0x3000 0x3FFF  -offset -0x3000  $(SREC_CKSUM_LENEG) 0x0FFF 1 1  -o $@ -Binary

$(R2_1): $(ROM1IHX)
	$(OBJC) $< $(SREC_ARGS) $(ROM1SIZE) -crop 0x0000 0x0FFF  -offset -0x0000  $(SREC_CKSUM_BTNOT) 0x0FFF 1 1  -o $@ -Binary

$(R3_1): $(ROM2IHX)
	$(OBJC) $< $(SREC_ARGS) $(ROM2SIZE) -crop 0x0000 0x0FFF  -offset -0x0000  $(SREC_CKSUM_BTNOT) 0x0FFF 1 1  -o $@ -Binary


# Using .BANK directive to separate code space of cpus, which causes 
# type 04 "Extended Linear Address" record to be emitted in sub and sub2. 
# srec_cat does not agree with aslink as to the format of this record, so I
# discard it. (TODO: try fake base e.g. BASE=0x010000 etc.)
#  http://srecord.sourceforge.net/man/man5/srec_intel.html
# Main CPU hex file does not contain type 04 so just do a straight cp

$(ROM0IHX):
	cd rom0 ; make
	cp rom0/ga0.i86  $@

$(ROM1IHX):
	cd rom0 ; make
	cat rom0/ga0_sub.i86 | sed /:00000004FC/d > $@

$(ROM2IHX):
	cd rom0 ; make
	cat rom0/ga0_sub2.i86 | sed /:00000004FC/d > $@


mkrom: $(ROMS)

##############
# test
#
test: mkrom
	$(MAMED) $(MAMEOPTS) \
	$(GAMENAME)


##############
# ident
#
ident: mkrom
	@-echo "Running mame -ident..."
	$(MAMED) -rompath . -romident  $(GAMENAME) | sed -n /NO\ MATCH/p	


##############
# clean
#
cleanroms:
	$(RM) $(ROMS)

clean: cleanroms
	$(RM) -f *\.ihx
	cd rom0 ; make clean

distclean: clean
	cd rom0 ; make distclean
