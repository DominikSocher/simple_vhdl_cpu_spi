-----------------------------------------------------------------------------
--Company: TEIS
--Engineer: Dominik Socher
--Created Date: Tuesday, November 24th 2020
-----------------------------------------------------------------------------
--File: c:\Users\Dominik\Documents\TEIS\VHDL_Comp\vga_sync.vhd
--Project: c:\Users\Dominik\Documents\TEIS\VHDL_Comp
--Target Device: 10M50DAF484C7G
--Tool version: Quartus 18.1 and ModelSim 10.5b
--Testbench file:
-----------------------------------------------------------------------------
--
-----------------------------------------------------------------------------
--Copyright (c) 2020 TEIS
-----------------------------------------------------------------------------
--
-----------------------------------------------------------------------------
--HISTORY:
--Date          By  Comments
------------    --- ---------------------------------------------------------
--2020-12-05    DS  Added port dispaly_on_out to signal when in pixel range
--2020-11-30    DS  Switched Name to use it with top level VGA_Controller
--
--
-----------------------------------------------------------------------------
--Description:
--       This is a VGA-Controller with 25 mhz clok
--       The component is generic with a max resolution of 640x480
--       Table 640x 480:        --horizontal timing 
--                              h_pixel_g      : integer := 640;
--                              h_frontporch_g : integer := 16;
--                              h_sync_g       : integer := 96;
--                              h_backporch_g  : integer := 48;
--                              --vertikal timing
--                              v_pixel_g      : integer := 480;
--                              v_frontporch_g : integer := 10;
--                              v_sync_g       : integer := 2;
--                              v_backporch_g  : integer := 33;
--                              addrwidth_g    : integer := 18 
--      Table 320x480:          --horizontal timing 
--                              h_pixel_g      : integer := 320;
--                              h_frontporch_g : integer := 4;
--                              h_sync_g       : integer := 48;
--                              h_backporch_g  : integer := 28;
--                              --vertikal timing
--                              v_pixel_g      : integer := 240;
--                              v_frontporch_g : integer := 4;
--                              v_sync_g       : integer := 1;
--                              v_backporch_g  : integer := 15;
--                              addrwidth_g    : integer := 17  
-----------------------------------------------------------------------------
--In Signals:
--      clock_50
--      reset_n
--      data_in
--Out Signals:
--      vga_hs
--      vga_vs
--      vga_r
--      vga_g
--      vga_b
--      address_out
--      frame_refresh_n
--      display_on_out
-----------------------------------------------------------------------------
--verified with the DE10-Lite board 
-----------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
ENTITY vga_sync IS
    GENERIC (
        --horizontal timing 
        h_pixel_g         : INTEGER := 640;
        h_frontporch_g    : INTEGER := 16;
        h_sync_g          : INTEGER := 96;
        h_backporch_g     : INTEGER := 48;
        --vertikal timing
        v_pixel_g         : INTEGER := 480;
        v_frontporch_g    : INTEGER := 10;
        v_sync_g          : INTEGER := 2;
        v_backporch_g     : INTEGER := 33;
        --rgb data width
        colorwidth_g      : INTEGER := 4;
        --adress width
        addrwidth_g       : INTEGER := 17
    );
    PORT (
        clk25_in          : IN STD_LOGIC;
        reset_n_in        : IN STD_LOGIC;
        data_in           : IN STD_LOGIC_VECTOR (2 DOWNTO 0);
        vga_vs_out        : OUT STD_LOGIC;
        vga_hs_out        : OUT STD_LOGIC;
        vga_r_out         : OUT STD_LOGIC_VECTOR (colorwidth_g - 1 DOWNTO 0);
        vga_g_out         : OUT STD_LOGIC_VECTOR (colorwidth_g - 1 DOWNTO 0);
        vga_b_out         : OUT STD_LOGIC_VECTOR (colorwidth_g - 1 DOWNTO 0);
        adress_out        : OUT STD_LOGIC_VECTOR (addrwidth_g - 1 DOWNTO 0);
        display_on_out    : OUT STD_LOGIC
    );
END vga_sync;

ARCHITECTURE rtl OF vga_sync IS

    CONSTANT x_period_c       : INTEGER := h_pixel_g + h_frontporch_g + h_sync_g + h_backporch_g; -- max. number x axis
    CONSTANT y_period_c       : INTEGER := v_pixel_g + v_frontporch_g + v_sync_g + v_backporch_g; -- max. number y axis
    CONSTANT hs_out_value_1_c : INTEGER := h_pixel_g + h_frontporch_g;
    CONSTANT hs_out_value_2_c : INTEGER := h_pixel_g + h_frontporch_g + h_backporch_g - 1;
    CONSTANT vs_out_value_1_c : INTEGER := v_pixel_g + v_frontporch_g;
    CONSTANT vs_out_value_2_C : INTEGER := v_pixel_g + v_frontporch_g + v_backporch_g;

    SIGNAL counter_x_s : INTEGER RANGE 0 TO x_period_c - 1 := 0;
    SIGNAL counter_y_s : INTEGER RANGE 0 TO y_period_c - 1 := 0;

BEGIN
    --Counters process -------------------------
    PROCESS (clk25_in, reset_n_in)
    BEGIN
        IF (reset_n_in = '0') THEN
            -- clear counter signals
            counter_x_s <= 0;
            counter_y_s <= 0;
        ELSIF rising_edge(clk25_in) THEN
            -- x_counter
            IF (counter_x_s >= x_period_c - 1) THEN --x_period clk cyckel for x
                counter_x_s <= 0;
                -- y_counter
                IF (counter_y_s = y_period_c - 1) THEN --y_period clk cyckel for y
                    counter_y_s <= 0;
                ELSE
                    counter_y_s <= counter_y_s + 1; -- increment y axis
                END IF;
            ELSE
                counter_x_s <= counter_x_s + 1; -- increment x axis
            END IF;
        END IF;
    END PROCESS;

    --Sync pulses ----------------------------------------
    vga_hs_out <= '0' WHEN ((counter_x_s >= hs_out_value_1_c) AND (counter_x_s <= hs_out_value_2_c)) ELSE
        '1';
    vga_vs_out <= '1' WHEN ((counter_y_s > vs_out_value_1_c) AND (counter_y_s <= vs_out_value_2_C)) ELSE
        '0';

    --Display time
    display_on_out <= '1' WHEN (counter_x_s < h_pixel_g) OR (counter_y_s < v_pixel_g) ELSE
        '0';

    --address out--calculation for 320*240-----------------
    adress_out <= STD_LOGIC_VECTOR(to_unsigned(counter_y_s/2 * 320 + counter_x_s/2, adress_out'length));
    --RGB signals out -------------------------------------
    vga_r_out <= "1" WHEN data_in = "001" ELSE
        (OTHERS => '0');
    vga_g_out <= "1" WHEN data_in = "010" ELSE
        (OTHERS => '0');
    vga_b_out <= "1" WHEN data_in = "100" ELSE
        (OTHERS => '0');
END rtl;