# Top-level Makefile.
#
# Running "make" builds the code, generates ROM files and runs mame ($MAMED).
#
# All binary file generation is done by srec_cat, which has lots of tricks...
# including the generation and placment of the proper checksum in each chip image!
#

OBJC= srec_cat 
RM= rm -f

##############
# ROM Info

ROM0BIN= ga0.bin
ROM1BIN= ga1.bin
ROM2BIN= ga2.bin

ROM0S19= rom0/ga0.i86
ROM1S19= rom1/ga1.i86
ROM2S19= rom2/ga2.i86

ROM0SIZE= 16384
ROM1SIZE= 4096
ROM2SIZE= 4096

# These are for xmame(0.36), xmame(0.79)
OFDIR= ./galaga
R1_1= 04m_g01.bin
R1_2= 04k_g02.bin
R1_3= 04j_g03.bin
R1_4= 04h_g04.bin
R2_1= 04e_g05.bin
R3_1= 04d_g06.bin

# These are for xmame(0.136)
OFDIR= ./galagao
R1_1= gg1-1.3p
R1_2= gg1-2.3m
R1_3= gg1-3.2m
R1_4= gg1-4.2l
R2_1= gg1-5.3f
R3_1= gg1-7.2c


#all: $(ROM0BIN) $(ROM1BIN) $(ROM2BIN) ident
all: test


SREC_ARGS= -intel -fill 0xff 0x0

# note: negative sign on offsets is intentional.
$(ROM0BIN): $(ROM0S19)
	$(OBJC) $< $(SREC_ARGS) $(ROM0SIZE) -crop 0x0000 0x0FFF  -offset -0x0000  -l-e-checksum-neg 0x0FFF 1 1  -o $(OFDIR)/$(R1_1) -Binary
	$(OBJC) $< $(SREC_ARGS) $(ROM0SIZE) -crop 0x1000 0x1FFF  -offset -0x1000  -l-e-checksum-neg 0x0FFF 1 1  -o $(OFDIR)/$(R1_2) -Binary
	$(OBJC) $< $(SREC_ARGS) $(ROM0SIZE) -crop 0x2000 0x2FFF  -offset -0x2000  -l-e-checksum-neg 0x0FFF 1 1  -o $(OFDIR)/$(R1_3) -Binary
	$(OBJC) $< $(SREC_ARGS) $(ROM0SIZE) -crop 0x3000 0x3FFF  -offset -0x3000  -l-e-checksum-neg 0x0FFF 1 1  -o $(OFDIR)/$(R1_4) -Binary

$(ROM1BIN): $(ROM1S19)
	$(OBJC) $< $(SREC_ARGS) $(ROM1SIZE) -crop 0x0000 0x0FFF  -offset -0x0000  -l-e-checksum-bitnot 0x0FFF 1 1  -o $(OFDIR)/$(R2_1) -Binary

$(ROM2BIN): $(ROM2S19)
	$(OBJC) $< $(SREC_ARGS) $(ROM2SIZE) -crop 0x0000 0x0FFF  -offset -0x0000  -l-e-checksum-bitnot 0x0FFF 1 1  -o $(OFDIR)/$(R3_1) -Binary


$(ROM0S19): $(wildcard *.inc) $(wildcard *.s) $(wildcard rom0/*.s)
	cd rom0 ; make

$(ROM1S19): $(wildcard *.inc) $(wildcard *.s) $(wildcard rom0/*.s)
	cd rom0 ; make
	cd rom0 ; cat ga0_sub.i86 | sed /:00000004FC/d > ../rom1/ga1.i86

$(ROM2S19): $(wildcard *.inc) $(wildcard *.s) $(wildcard rom0/*.s)
	cd rom0 ; make
	cd rom0 ; cat ga0_sub2.i86 | sed /:00000004FC/d > ../rom2/ga2.i86

# MAME specific setup.
MAMED= /cygdrive/c/home/myjunk/mame0136/mamed.exe
MAMEOPTS= -debug -skip_gameinfo -rompath .
MAMEOPTS+= -window -nomaximize
GAMENAME= galagao


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


mkrom: $(ROM0BIN) $(ROM1BIN) $(ROM2BIN)


##############
# clean
#
clean:
	$(RM) *.rel *.bin *.s19 
	cd $(OFDIR) ; $(RM) $(R1_1) $(R1_2) $(R1_3) $(R1_4) $(R2_1) $(R3_1)
	cd rom0 ; make clean
	cd rom1 ;  $(RM) *.rel *.s19 *.lst *.map *.noi *.lk *.ihx *.sym *.asm *.i86
	cd rom2 ;  $(RM) *.rel *.s19 *.lst *.map *.noi *.lk *.ihx *.sym *.asm *.i86

