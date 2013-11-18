/*******************************************************************************
 **  galag: precise re-implementation of a popular space shoot-em-up
 **  galag.c
 **
 **  main file for application interface to MAME code
 *******************************************************************************/
/*
 ** header file includes
 */
#include "galag.h"
#include "driver.h"

/*
 ** defines and typedefs
 */
#ifndef XMAME

#define code_pressed(_KEYCODE_) \
  osd_key_pressed(_KEYCODE_)

#define  KEYCODE_LCONTROL OSD_KEY_CONTROL
#define  KEYCODE_RIGHT    OSD_KEY_RIGHT
#define  KEYCODE_LEFT     OSD_KEY_LEFT
#define  KEYCODE_ESC      OSD_KEY_ESC
#define  KEYCODE_1        OSD_KEY_1
#define  KEYCODE_2        OSD_KEY_2
#define  KEYCODE_3        OSD_KEY_3
#endif // XMAME

/*
 ** extern declarations defined in other files
 */
// functions
extern void galaga_vh_screenrefresh(struct osd_bitmap *bitmap);
extern void pengo_sh_update(void);

// variables
extern struct RunningMachine *Machine;


/*
 ** non-static external definitions this file or others
 */

// globals
uint8 irq_acknowledge_enable_cpu0;
uint8 irq_acknowledge_enable_cpu1;
uint8 nmi_acknowledge_enable_cpu2;

// SFR locations
uint8 _sfr_dsw1; //  $$6800
uint8 _sfr_dsw2; //  $$6801
uint8 _sfr_dsw3; //  $$6802
uint8 _sfr_dsw4; //  $$6803
uint8 _sfr_dsw5; //  $$6804
uint8 _sfr_dsw6; //  $$6805
uint8 _sfr_dsw7; //  $$6806
uint8 _sfr_dsw8; //  $$6807

uint8 _sfr_6820; //  $$6820  ; maincpu IRQ acknowledge/enable
uint8 _sfr_6821; //  $$6821  ; CPU-sub1 IRQ acknowledge/enable)
uint8 _sfr_6822; //  $$6822  ; CPU-sub2 nmi acknowledge/enable
uint8 _sfr_6823; //  $$6823  ; 0:halt 1:enable CPU-sub1 and CPU-sub2

uint8 _sfr_watchdog; // $$6830


/*
 ** static external definitions in this file
 */

// functions
static void vblank_work(void);


/***************************************************************************

 * I don't know what will go here but it's here.

 ***************************************************************************/
void bugs_init(void)
{
}

/***************************************************************************

 Emulate the custom IO chip.

 In the real Galaga machine, the chip would cause an NMI on CPU #1 to ask
 for data to be transferred. We don't bother causing the NMI, we just look
 into the CPU register to see where the data has to be read/written to, and
 emulate the behaviour of the NMI interrupt.

 ***************************************************************************/
void c_io_cmd_wait(void)
{
    //    struct RunningMachine *Machine = pMachine ;
#ifndef XMAME
    if (Machine->samples->sample[0])
        osd_play_sample(7, (unsigned char *)Machine->samples->sample[0]->data,
                        Machine->samples->sample[0]->length,
                        Machine->samples->sample[0]->smpfreq,
                        Machine->samples->sample[0]->volume, 0);
#endif // XMAME
}

/***************************************************************************

  Execute periodic tasks

 ***************************************************************************/
static void vblank_work(void)
{
    // Execute the "CPU0" Vblank interrupt (RST38).
    if (irq_acknowledge_enable_cpu0)
        cpu0_rst38();

    // Execute the other sub-CPU's if they are enabled.

    // "CPU1" has a Vblank interrupt (RST38).

    // if ( ! galaga_halt_w )
    if (irq_acknowledge_enable_cpu1)
        cpu1_rst38();

    // CPU2 has 2 interrupts per frame (NMI)
    if (nmi_acknowledge_enable_cpu2)
    {
        cpu2_NMI();
        cpu2_NMI();
    }
}

/***************************************************************************

  This function takes care of refreshing the screen, processing user input,
  and throttling the emulation speed to obtain the required frames per second.

  IN: blocking
        1 == blocking, i.e. read keys, doesn't return until vblank complete.
        0 == non-blocking, i.e. read keys but return if not vblank (not all
             that useful actually).

 ***************************************************************************/
int _updatescreen(int blocking)
{
    struct RunningMachine *pMachine = Machine;

    static uclock_t prev;

    static int this1, last1;
    static int this2, last2;
    static int this3, last3;
    static int thisct, lastct;


    thisct = code_pressed(KEYCODE_LCONTROL);

    if (thisct && lastct != thisct)
    {
        io_input[1] &= ~0x10; // see note for f_1F04
    }
    else
    {
        io_input[1] |= 0x10; // see note for f_1F04
    }
    lastct = thisct;

    if ( code_pressed(KEYCODE_RIGHT) )
    {
        io_input[1] &= ~2;
    }
    else
    {
        io_input[1] |= 2;
    }

    if ( code_pressed(KEYCODE_LEFT) )
    {
        io_input[1] &= ~8;
    }
    else
    {
        io_input[1] |= 8;
    }


    /* if the user pressed ESC, stop the emulation */
    if ( code_pressed(KEYCODE_ESC) ) return 1;

    // get keys for coin-in switch and start button, which need to be debounced

    this3 = code_pressed(KEYCODE_3);
    if (this3 && last3 != this3)
    {
        if (io_input[0] < 255)
        {
            io_input[0]++;
        }
    }
    last3 = this3;

    this1 = code_pressed(KEYCODE_1);
    if (this1 && last1 != this1)
    {
        if (io_input[0] > 0)
        {
            io_input[0]--;
        }
    }
    last1 = this1;

    this2 = code_pressed(KEYCODE_2);
    if (this2 && last2 != this2)
    {
        if (io_input[0] > 0)
        {
            io_input[0] -= 2;
        }
    }
    last2 = this2;


    if (blocking)
    {
        uclock_t curr;
#ifndef XMAME
        pengo_sh_update(); /* update sound */
        osd_update_audio();
#else
        pengo_sound_w(0, 0);
#endif // XMAME

        galaga_vh_screenrefresh(pMachine->scrbitmap); /* update screen */
#ifndef XMAME
        osd_update_display();
#else
        osd_update_video_and_audio();
#endif // XMAME

        /* now wait until it's time to trigger the interrupt */
        do
        {
            curr = uclock();
        }
        while (curr - prev < UCLOCKS_PER_SEC / pMachine->drv->frames_per_second);

        vblank_work();
        prev = curr;
    }
    else // not blocking
    {
        uclock_t curr;

        curr = uclock();

        /* only call the vblank interrupt if time is up */
        if (curr - prev > UCLOCKS_PER_SEC / pMachine->drv->frames_per_second)
        {
            vblank_work();
            //            prev = prev + UCLOCKS_PER_SEC/g_machine_driver.frames_per_second;

            prev = curr;
#ifndef XMAME
            pengo_sh_update(); /* update sound */
            osd_update_audio();
#else
            pengo_sound_w(0, 0);
#endif // XMAME

            galaga_vh_screenrefresh(pMachine->scrbitmap); /* update screen */
#ifndef XMAME
            osd_update_display();
#else
            osd_update_video_and_audio();
#endif // XMAME
        }
    }

    return 0;
}

/***************************************************************************

  Main entry point for game executive.

 ***************************************************************************/
int bugs_exec(void)
{
    io_input[0] = 1; // tmp
    io_input[0] = 0; // tmp

    // probably need to break this into smaller functions, i.e. :
    // RAM_test() ... ...halt CPU #2 and #3 .. cpu #3 nmi Z80_IGNORE_INT
    // romtest_mgr() ... enable sub CPUs
    cpu0_init();

    cpu1_init();

    cpu2_init();

    svc_test_mgr();

    j_Game_init();

    if (0 != j_Game_start()) goto getout;

    if (0 != game_state_ready()) goto getout;

    if (0 != game_mode_start()) goto getout;

    game_runner(); // if (0 != game_runner()) goto getout;

    return 0;

getout:
    return 1;
}