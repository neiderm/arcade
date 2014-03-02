/*******************************************************************************
 **  galag: precise re-implementation of a popular space shoot-em-up
 **  gg1-4.s (gg1-4.2l)
 **
 **  Hi-score dialog, power-on memory tests, and service-mode menu functions
 **
 *******************************************************************************/
#include "galag.h"

mchn_cfg_t mchn_cfg;


/*=============================================================================
;;  Description: machine power-on/self-test
;;   RAM and ROM tests (do not know if graphic patterns will be too fast to see?).
;;   'RAM OK' and 'ROM OK' actually shown right side up, but flip screen gets
;;   set because of the check that is done on the IO input value.
;;   Service-mode menus not implemented and also video-ram test pattern is
;;   shoved in here as well.
;;
;;   In C code, the following must be broken out of cpu0_init if it depends
;;   on cpu1_init  and/or cpu2_init.
;; IN:
;;  ...
;; OUT:
;;  ...
;;---------------------------------------------------------------------------*/
uint8 cpu0_post(void)
{
    uint16 HL, DE, BC;

// jp_RAM_test:

    // enable f_05BE in CPU-sub1 (empty task) ... disabled in game_ctrl start
    cpu1_task_en[0] = 0x07; // skips to f_05BE in CPU-sub task-table

//jp   j_romtest_mgr

//j_Test_menu_init:

// call c_svc_updt_dsply

    // goes in c_svc_updt_dsply()
    mchn_cfg.bonus[0] = 0x02;
    mchn_cfg.bonus[1] = 0x06;


    // Initialize scheduler table before interrupts are enabled (otherwise
    // task scheduler could infinite loop!)
    task_actv_tbl_0[0] = 0x20; // only task 0 (empty task) can be called


    // wait 02 frames to verify that CPU-sub1 is alive and updating the frame counter
    ds3_92A0_frame_cts[0] = 0;
    while (ds3_92A0_frame_cts[0] < 2)
    {
        _updatescreen(1); // verify that CPU-sub1 is alive
    }


    //  setup IO command params for bang sound
    //        ld   (0x7100),a    ; IO cmd ($A8 -> bang sound)
    c_io_cmd_wait();

    // setup interrupt mode and toggle the latch
    irq_acknowledge_enable_cpu0 = 1; // enable cpu0_rst38 (_post)


    // wait 8 frames (while test sound??)



    // j_36BA_Machine_init:


    // wait 8 frame counts


    // jp   nc,j_Test_menu_proc

    // synchronize with next frame transition.
    //  while ( frame_cts[0] == prev_frame_cts[0] )

    // dips would be read here
    mchn_cfg.rank = 3; // default to 3->easy


    // j_36BA_Machine_init:

    HL = 0;

    // drawing the cross hatch pattern - tile ram layout is pretty clumsy!
    BC = 0x10;
    while (BC-- > 0)
    {
        *(m_tile_ram + HL) = 0x28;
        HL++;
        *(m_tile_ram + HL) = 0x27;
        HL++;
    }

    BC = 0x10;
    while (BC-- > 0)
    {
        *(m_tile_ram + HL) = 0x2D;
        HL++;
        *(m_tile_ram + HL) = 0x2B;
        HL++;
    }

    BC = 0x10;
    while (BC-- > 0)
    {
        *(m_tile_ram + HL) = 0x28;
        HL++;
        *(m_tile_ram + HL) = 0x2D;
        HL++;
    }

    BC = 0x10;
    while (BC-- > 0)
    {
        *(m_tile_ram + HL) = 0x27;
        HL++;
        *(m_tile_ram + HL) = 0x2B;
        HL++;
    }

    // remainder of cross hatch pattern is drawn by copy.
    DE = HL;
    HL = 0x0040;
    BC = 0x0340;
    while (BC-- > 0)
    {
        *(m_tile_ram + DE) = *(m_tile_ram + HL);
        DE++;
        HL++;
    }

    HL = 0; // #m_tile_ram
    BC = 0x0040;
    while (BC-- > 0)
    {
        *(m_tile_ram + DE) = *(m_tile_ram + HL);
        DE++;
        HL++;
    }


    // wait about two seconds before checking Test-switch.
    ds3_92A0_frame_cts[0] = 0;
    while (ds3_92A0_frame_cts[0] < 0x80)
    {
        BC = _updatescreen(1); // before checking Test-switch.
        if (0 != BC)
        {
            return BC;
        }
    }
    return 0; //        jp   j_Game_init ... g_init
}

