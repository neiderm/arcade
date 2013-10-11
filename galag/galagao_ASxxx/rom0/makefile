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

# Locate the standard SDCC segments. It is possible that _CODE does not exist
# if all files have been compiled with "sdcc --codeseg". As a front-end to the 
# linker, sdcc allows the default C code and data segments to be located i.e.
#   --code-loc $(C_CODE_START) --data-loc $(C_DATA_START)
# In aslink we use the standard '-b' linker arguments to locate all segments:

#  CSEGDEF+= -b _CODE=0x3c00
  CSEGDEF+= -b _DATA=0x8A50

# Locate any additional code segments created by "sdcc --codeseg" ...note 
# name decoration (underscore) added by SDCC.
#  CSEGDEF+= -b _ASDF=0x3c00


# TODO: merge sub.mak into here, since there are no longer separate builds for each CPU .
include ../sub.mak

