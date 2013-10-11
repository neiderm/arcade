/*******************************************************************************
 **  galag: precise re-implementation of a popular space shoot-em-up
 **  gg1-4.s (gg1-4.2l)
 **
 **  Hi-score dialog, power-on memory tests, and service-mode menu functions
 **  combined into gg1-4 and removed files reset.s and svc_mode.s
 **  from branch "sdasz80_03172012".
 **
 *******************************************************************************/
#include "galag.h"

struct_mchn_cfg mchn_cfg;

/*
 *
 */
void cpu0_init(void)
{
    // goes in c_svc_updt_dsply()
    mchn_cfg.bonus[0] = 0x02;
    mchn_cfg.bonus[1] = 0x06;

    // enable f_05BE in CPU-sub1 (empty task) ... disabled in game_ctrl start (... why 7?)
    cpu1_task_en [0] = 0x07;
}

/*
 *
 */
void svc_test_mgr(void)
{
    uint16 HL, DE, BC;

    // Initialize scheduler table before interrupts are enabled (otherwise
    // task scheduler could infinite loop!)
    task_actv_tbl_0[0] = 0x20; // only task 0 (empty task) can be called



    // wait 02 frames to verify that CPU-sub1 is alive and updating the frame counter
    ds3_92A0_frame_cts[0] = 0;
    while (ds3_92A0_frame_cts[0] < 2)
    {
        int usres;
        if (0 != (usres = _updatescreen(0))) // 1=blocking
        {
            /* goto getout; */ // 1=blocking
        }
    }


    // setup interrupt mode and toggle the latch
    irq_acknowledge_enable_cpu0 = 1;

    //  setup IO command params for bang sound
    //        ld   (0x7100),a    ; IO cmd ($A8 -> bang sound)
    c_io_cmd_wait();


    // wait 8 frames (while test sound??)



    // j_36BA_Machine_init:


    // wait 8 frame counts


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
        int usres;
        if (0 != (usres = _updatescreen(0))) // 1=blocking
        {
            /* goto getout; */ // 1=blocking
        }
    }
}

