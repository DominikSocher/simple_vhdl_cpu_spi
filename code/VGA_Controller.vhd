-----------------------------------------------------------------------------
--Company: TEIS
--Engineer: Dominik Socher
--Created Date: Monday, November 30th 2020
-----------------------------------------------------------------------------
--File: c:\Users\Dominik\Documents\TEIS\VHDL_Comp\vga_controller.vhd
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
--Date          By     Comments
------------    ---    ------------------------------------------------------
--
-----------------------------------------------------------------------------
--Description:
--        This is the top nivau of the vga_controller. The Controller has 3 
--        Components:
--                  --Phase locked loop 50MHz to 25 MHz
--                  --Dual-Port-RAM
--                  --VGA_Sync
--        
-----------------------------------------------------------------------------
--In Signals:
--        reset_n_in -- aktiv low reset signal
--        clk_50_in  -- 50 MHz system clock
--        we_b_n     -- write enable port_b RAM
--        data_b     -- data port_b RAM 
--        adress_b   -- adress port_b RAM 
--       
--Out Signals:
--      vga_hs       -- horizontal sync 
--      vga_vs       -- vertical sync
--      vga_r        -- red color
--      vga_g        -- green color
--      vga_b        -- blue color
--      frame_refresh_n -
-----------------------------------------------------------------------------
--verified with the DE10-Lite board 
-----------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY vga_controller IS
    PORT (
        reset_n_in     : IN STD_LOGIC := '0';
        clk_50_in      : IN STD_LOGIC := '0';
        we_b_in        : IN STD_LOGIC;
        data_b_in      : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        adress_b_in    : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        --VGA
        vga_vs_out     : OUT STD_LOGIC;
        vga_hs_out     : OUT STD_LOGIC;
        vga_r_out      : OUT STD_LOGIC_VECTOR (0 DOWNTO 0);
        vga_g_out      : OUT STD_LOGIC_VECTOR (0 DOWNTO 0);
        vga_b_out      : OUT STD_LOGIC_VECTOR (0 DOWNTO 0);
        display_on_out : OUT STD_LOGIC
    );
END ENTITY;

ARCHITECTURE rtl OF VGA_Controller IS

    SIGNAL clk25_s    : STD_LOGIC;
    --signals memory
    SIGNAL data_a_s   : STD_LOGIC_VECTOR (2 DOWNTO 0) := "000";
    SIGNAL adress_a_s : STD_LOGIC_VECTOR (15 DOWNTO 0);

    COMPONENT pll_25MHz
        PORT (
            inclk0 : IN STD_LOGIC := '0';
            c0     : OUT STD_LOGIC;
           locked : OUT STD_LOGIC
        );
    END COMPONENT;

    COMPONENT true_dual_port_ram_dual_clock
        GENERIC (
            DATA_WIDTH : NATURAL := 8;
            ADDR_WIDTH : NATURAL := 6
        );
        PORT (
            clk_a  : IN STD_LOGIC;
            clk_b  : IN STD_LOGIC;
            addr_a : IN STD_LOGIC_VECTOR((ADDR_WIDTH - 1) DOWNTO 0);
            addr_b : IN STD_LOGIC_VECTOR((ADDR_WIDTH - 1) DOWNTO 0);
            data_a : IN STD_LOGIC_VECTOR((DATA_WIDTH - 1) DOWNTO 0);
            data_b : IN STD_LOGIC_VECTOR((DATA_WIDTH - 1) DOWNTO 0);
            we_a   : IN STD_LOGIC := '1';
            we_b   : IN STD_LOGIC := '1';
            q_a    : OUT STD_LOGIC_VECTOR((DATA_WIDTH - 1) DOWNTO 0);
            q_b    : OUT STD_LOGIC_VECTOR((DATA_WIDTH - 1) DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT vga_sync
        GENERIC (
            --horizontal timing 
            h_pixel_g      : INTEGER := 640;
            h_frontporch_g : INTEGER := 16;
            h_sync_g       : INTEGER := 96;
            h_backporch_g  : INTEGER := 48;
            --vertikal timing
            v_pixel_g      : INTEGER := 480;
            v_frontporch_g : INTEGER := 10;
            v_sync_g       : INTEGER := 2;
            v_backporch_g  : INTEGER := 33;
            --rgb data width
            colorwidth_g   : INTEGER := 4;
            --adress width
            addrwidth_g    : INTEGER := 16
        );
        PORT (
            clk25_in       : IN STD_LOGIC;
            reset_n_in     : IN STD_LOGIC;
            data_in        : IN STD_LOGIC_VECTOR (2 DOWNTO 0);
            vga_vs_out     : OUT STD_LOGIC;
            vga_hs_out     : OUT STD_LOGIC;
            vga_r_out      : OUT STD_LOGIC_VECTOR (colorwidth_g - 1 DOWNTO 0);
            vga_g_out      : OUT STD_LOGIC_VECTOR (colorwidth_g - 1 DOWNTO 0);
            vga_b_out      : OUT STD_LOGIC_VECTOR (colorwidth_g - 1 DOWNTO 0);
            adress_out     : OUT STD_LOGIC_VECTOR (addrwidth_g - 1 DOWNTO 0);
            display_on_out : OUT STD_LOGIC
        );
    END COMPONENT;
BEGIN

    pll_25MHz_inst : pll_25MHz
    PORT MAP(
        inclk0  => clk_50_in,
        c0      => clk25_s,
        locked  => OPEN
    );

    ram_inst : true_dual_port_ram_dual_clock
    GENERIC MAP(
        DATA_WIDTH => 3,
        ADDR_WIDTH => 16
    )
    PORT MAP(
        clk_a   => clk25_s,
        clk_b   => clk_50_in,
        addr_a  => adress_a_s,
        addr_b  => adress_b_in,
        data_a  => (OTHERS => '0'),
        data_b  => data_b_in,
        we_a    => '0',
        we_b    => we_b_in,
        q_a     => data_a_s,
        q_b     => OPEN
    );

    vga_sync_inst : vga_sync
    GENERIC MAP(
        --horizontal timing 
        h_pixel_g      => 640,
        h_frontporch_g => 16,
        h_sync_g       => 96,
        h_backporch_g  => 48,
        --vertikal timing
        v_pixel_g      => 480,
        v_frontporch_g => 10,
        v_sync_g       => 2,
        v_backporch_g  => 33,
        --rgb data width
        colorwidth_g   => 1,
        --adress width
        addrwidth_g    => 16
    )
    PORT MAP(
        clk25_in       => clk25_s,
        reset_n_in     => reset_n_in,
        data_in        => data_a_s,
        vga_vs_out     => vga_vs_out,
        vga_hs_out     => vga_hs_out,
        vga_r_out      => vga_r_out,
        vga_g_out      => vga_g_out,
        vga_b_out      => vga_b_out,
        adress_out     => adress_a_s,
        display_on_out => display_on_out
    );
    

END rtl;