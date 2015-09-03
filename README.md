ARCADE! (formerly ... eightysArcade)
====================================

Precise translation of arcade games from the 1980's

This project and repository supercededs the previous one at 
https://github.com/gary-seven/eightysArcade

Summary:
All of the game logic is to be tranlated from assembly language.
MAME is used only to provide graphics and sound rendering.

Linux:

  git clone https://github.com/gary-seven/arcade.git
  cd arcade/galag/c_code/
  tar xvjf ../../support/xmame-0.79.1.tar.bz2 
  ln -s xmame-0.79.1/ xmame
  codeblocks proj/cblin/galag/galag.cbp  &
  cd xmame
  cat ../../../support/xmame-0.79.1_gsim.pat  | patch -p1 

 xmame-0.78.1 is the first release that would build and link against Alsa 
 on my Ubuntu systems ("now builds against ALSA 1.0", from doc/changes.unix).
 I have provided arcade/support/xmame-0.79.1.tar.bz2 (xmame archives are 
 really hard to find on the internet these days), and an accompanying 
 patch for integration with the game code - there is something peculiar with
 several versions of XMAME prior to 79.1 ... galaga hangs at the self-test.

 On Ubuntu, several development packages may need to be installed:
 libx11-dev (X11/xlib.h),  
 libxext-dev (X11/extensions/XShm.h)
 libz-dev
 libxi-dev (X11/extensions/XInput.h)
 libxv-dev (X11/extensions/Xv.h)
 libexpat1-dev (expat.h)
 libncurses-dev (for MAME built-in debugger)
 libusb-dev (maybe ... in xmame-0.67.1)

 XMAME version .67.1 through .86.1 do not appear correctly on my Ubuntu systems,
 running in a window, using X11 as the display
 "Using a Visual with a depth of 32bpp.
  Using private color map."
 ... but the black background color is transparent! A hack-around 
 is included in the patch.

 Code:Blocks project to build the game is in: 
   arcade/galag/c_code/proj/cblin/galag/

 Also in cblin/galag/, there needs to be a directory containing a few more
 files which you will have to find, these include "04D_G06.BIN" and several 
 others which are not distributed here.


Windows:
 use https://github.com/gary-seven/MAME_hack/tree/master/mame36/mame

 Copy mame36/mame to arcade/galag/c_code/

 Code:Blocks project to build the game is in: 
   arcade/galag/c_code/proj/cbwin/galag/

 Also in cbwin/galag/, there needs to be a directory containing a few more
 files which you will have to find, these include "04D_G06.BIN" and several 
 others which are not distributed here.

