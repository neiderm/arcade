# Gyaraga

Commented and compilable assembly source for a popular arcade game from the 1980's

## Prerequisites:

* Ubuntu Linux
* `srec_cat` - install from package distro: `apt install srecord`
* Optional: _Code::Blocks_
    * A Code::Blocks project file (.cbp) is provided that can make use of a lexer config file for Z80:
   (_ASxxx/contrib/lexer_zilog_z80.xml)
* _MAME_ (Multi Arcade Machine Emulator) for verifying rom checksums
    * `apt-get install mame`
    * Currently v0.242
    * See [here](https://github.com/neiderm/MAME_hack.git) for instructions to build legacy xmame sources.
* The following binary files (Namco rev. B):
    * gg1-9.4l (07h_g09.bin)  gfx1
    * gg1-11.4d (07m_g08.bin)  gfx2
    * gg1-10.4f (07e_g10.bin)  gfx2
    * prom-5.5n (5n.bin)  palette
    * prom-4.2n (2n.bin)  char lookup
    * prom-3.1c (1c.bin)  sprite lookup
    * prom-1.1d (1d.bin)  custom chip firmware
    * prom-2.5c (5c.bin)  custom chip firmware
* asxxxx assembler suite by Alan R. Baldwin:
    * https://shop-pdp.net/ashtml/asxget.php
    * https://shop-pdp.net/_ftp/asxxxx/av5p10.zip

## Build

The build relies upon the asxxxx assembler by Alan R. Baldwin, which has necessary capability of assembling to individual relocatable files, that are then linked into ROM images with the proper address range. 

The assembly and linker must be built from an older asxxxx source (5.10), as the newer versions seem to be breaking the build (todo investigate).

``` shell
cd asxv5pxx/asxmak/linux/build
make
`cp asez8 aslink /usr/local/bin/`
```

``` shell
cd galagao_ASxxx
make distclean
make
```

The following files should be generated in the ROM directory:
* gg1-1.3p (04m_g01.bin)  main cpu
* gg1-2.3m (04k_g02.bin)  main cpu
* gg1-3.2m (04j_g03.bin)  main cpu
* gg1-4.2l (04h_g04.bin)  main cpu
* gg1-5.3f (04e_g05.bin)  sub cpu 1
* gg1-7.2c (04d_g06.bin)  sub cpu 2

MAME should run with the newly generated program ROMs, and there should be no SHA errors.
If the source is modified and then rebuilt, MAME should report SHA errors on the affected ROM image(s).

