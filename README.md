ARCADE! (formerly ... eightysArcade)
====================================

Precise translation of arcade games from the 1980's

This project and repository supercededs the previous one at 
https://github.com/gary-seven/eightysArcade

Summary:
 - ASxxx project: 
   Assembly sources to generate exact image of machine code.
   Requires asez80 assembler by Alan R. Baldwin to build:
     ftp://shop-pdp.net/pub/asxxxx/av5p10.zip
   Requires srecord-1.64:
     http://srecord.sourceforge.net/srecord-1.64.tar.gz
   Code::Blocks project (.cbp) is provided to browse/edit the aseembly code
    (C::B lexer config in _ASxxx/contrib/lexer_zilog_z80.xml). 
 - c_code project:
   All of the game logic is to be tranlated from assembly language - MAME is 
    used only to render graphics and sound.

The following applies specifically to Linux:

  c_code project found in c_code/proj/cblin/

  In the c_code/ directory:
    tar xvjf ../../support/xmame-0.79.1.tar.bz2 
    ln -s xmame-0.79.1/ xmame
    cd xmame
    cat ../../../support/xmame-0.79.1_gsim.pat | patch -p1 

 On Ubuntu, several development packages may need to be installed, including:
 (For xmame)
   libx11-dev (X11/xlib.h),  
   libxext-dev (X11/extensions/XShm.h)
   libz-dev
   libxi-dev (X11/extensions/XInput.h)
   libxv-dev (X11/extensions/Xv.h)
   libexpat1-dev (expat.h)
   libncurses-dev (for MAME built-in debugger)
   libusb-dev (maybe ... in xmame-0.67.1)
   libasound2-dev
 (For srecord)
   install g++
   libboost-dev
   libgcrypt11-dev
   libtool

 I mostly use older versions of MAME (xmame) as I am working on low-spec
 machines like single-core PCs and ARM boards. I have provided 
  "arcade/support/xmame-0.79.1.tar.bz2" (xmame archives are really hard to find
 on the internet these days). The patch is required to make a few small fixes
 and for integration with the game code.

 The c_code project .cbp will incorporate the xmame sources and provide build
 configurations for both the C translation as well as the xmame emulator.
 In order to run the binaries produced by the ASxxx configuration, use xmame 
 executable built in the Code::Blocks project, or build with make as follows:

     make -f makefile.unix SOUND_ALSA=1

 Assembly files are also built by make ... see _ASxxx/Makefile, there are 
 different names which are created - this needs to be handled better, but the 
 purpose was to allow operation in multiple OS environments where I ended up 
 with different versions of (x)mame to support.

 You will undoubtably end up finding that there are some other binary files 
 needed by MAME to get this all working - eventually I intend to eliminate 
 these dependencies, and am currently experimenting with turaco utility to 
 dynamically generate graphics files ("04D_G06.BIN" and others which are not 
 distributed here). For now, you'll just have to find these on your own!


Windows configuration:

 Unfortunately I haven't had a chance to finish up this part of the setup
 documentation, other than making a note of a couple blatant differences in
 the project configuration compared to the Linux configuration.

 c_code project found in c_code/proj/cbwin

 c_code is based on MAME v0.36:

   https://github.com/gary-seven/MAME_hack.git
 
 Copy or link MAME_hack/mame36/mame/ to into c_code/ directory.

 Note: different versions of binary files are needed because the c_code is 
 tied to MAME-0.36, whereas the ASxxx/Makefile I had generally used MAME-0.136.
 You are left to your own resourcefulness to obtain these files.

