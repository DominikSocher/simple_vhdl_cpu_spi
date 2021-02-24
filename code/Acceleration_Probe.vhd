-----------------------------------------------------------------------------
--Company: TEIS
--Engineer: Dominik Socher
--Created Date: Tuesday, January 12th 2021
-----------------------------------------------------------------------------
--File: c:\Users\Dominik\Documents\TEIS\VHDL_systemkurs\dominik_socher_vhdl2_ingenjorsjobb_a\design\Acceleration_Probe.vhd
--Project: c:\Users\Dominik\Documents\TEIS\VHDL_systemkurs\dominik_socher_vhdl2_ingenjorsjobb_a\design
--Target Device: 10M50DAF484C7G
--Tool version: Quartus 18.1 and ModelSim 10.5b
--Testbench file:
-----------------------------------------------------------------------------
--
-----------------------------------------------------------------------------
--Copyright (c) 2021 TEIS
-----------------------------------------------------------------------------
--
-----------------------------------------------------------------------------
--HISTORY:
--Date          By     Comments
------------    ---    ------------------------------------------------------
--
-----------------------------------------------------------------------------
--Description:
--        This is the top file of the construction. The system consist of
--        a simple CPU with instruction ROM and a SPI co-processor. The 
--        system logs data from an acceleration sensor (ADXL 345) saves the
--        data in a RAM an presents it on a VGA screen.
-----------------------------------------------------------------------------
--In Signals:
--        
--        
--Out Signals:
--        
--        
-----------------------------------------------------------------------------
--verified with the DE10-Lite board 
-----------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

--===========================================================================
--                        Define input/output ports
--===========================================================================
ENTITY Acceleration_Probe IS
    PORT (
        clk_50_in   : IN STD_LOGIC;                          -- system clock input 50 MHz
        rst_n_in    : IN STD_LOGIC;                          -- reset input aktive low asynchronous
        --VGA port
        vga_vs_out  : OUT STD_LOGIC;                         -- VGA : vertikal sync
        vga_hs_out  : OUT STD_LOGIC;                         -- VGA : horisontal sync
        vga_r_out   : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);      -- VGA : red
        vga_g_out   : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);      -- VGA : green
        vga_b_out   : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);      -- VGA : blue
        --SPI port
        miso_in     : IN STD_LOGIC;                          -- SPI : master in slave out
        mosi_out    : OUT STD_LOGIC;                         -- SPI : master out slave in
        sck_out     : OUT STD_LOGIC;                         -- SPI : serial clock
        ss_out      : OUT STD_LOGIC_VECTOR (0 DOWNTO 0));    -- SPI : slave select
END Acceleration_Probe;

ARCHITECTURE rtl OF Acceleration_Probe IS

--===========================================================================
--                        Components
--===========================================================================
    COMPONENT input_filter
        PORT (
            clk50_in       : IN STD_LOGIC;    --system clock
            reset_n_in     : IN STD_LOGIC;    -- input asynchronous
            reset_sync_out : OUT STD_LOGIC);  -- output synchronous
    END COMPONENT;

    COMPONENT spi_controller
    GENERIC (
        clk_freq       : INTEGER := 50);                      --system clock frequency in MHz
    PORT (
        clk_in         : IN STD_LOGIC;                        --system clock
        rst_n_in       : IN STD_LOGIC;                        --active low reset
        data_bus_in    : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);   -- instrcution adxl345
        miso           : IN STD_LOGIC;                        --SPI : master in, slave out
        data_ready_in  : IN STD_LOGIC;                        -- proceed signal form main processor
        sclk           : OUT STD_LOGIC;                       --SPI : serial clock
        ss_n           : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);    --SPI : slave select
        mosi           : OUT STD_LOGIC;                       --SPI : master out, slave in
        hold_main_out  : OUT STD_LOGIC;                       -- hold main processor 
        rx_data_out    : OUT STD_LOGIC_VECTOR(15 DOWNTO 0));  --z-axis acceleration data         
    END COMPONENT spi_controller;

    COMPONENT VGA_Controller
        PORT (
            reset_n_in     : IN STD_LOGIC := '0';              --reset input active low
            clk_50_in      : IN STD_LOGIC := '0';              --system clock
            we_b_in        : IN STD_LOGIC;                     --write enable ram
            data_b_in      : IN STD_LOGIC_VECTOR(2 DOWNTO 0);  --data input ram
            adress_b_in    : IN STD_LOGIC_VECTOR(15 DOWNTO 0); --addres input ram
            --VGA 
            vga_vs_out     : OUT STD_LOGIC;                 
            vga_hs_out     : OUT STD_LOGIC;
            vga_r_out      : OUT STD_LOGIC_VECTOR (0 DOWNTO 0);
            vga_g_out      : OUT STD_LOGIC_VECTOR (0 DOWNTO 0);
            vga_b_out      : OUT STD_LOGIC_VECTOR (0 DOWNTO 0);
            display_on_out : OUT STD_LOGIC);
    END COMPONENT;
    
    COMPONENT vga_grafic
    PORT (
        clk50_in      : IN STD_LOGIC;                       --system clock
        reset_n_in    : IN STD_LOGIC;                       --reset active low
        data_cpu_in   : IN STD_LOGIC_VECTOR (15 DOWNTO 0);  --raw data input from accelerometer controller
        data_ready_in : IN STD_LOGIC;                       -- reday signal from accelerometer controller
        --memory
        we_b_out      : OUT STD_LOGIC;                      --we to vga_ram
        data_b_out    : OUT STD_LOGIC_VECTOR (2 DOWNTO 0);  --data to vga ram
        adress_b_out  : OUT STD_LOGIC_VECTOR (15 DOWNTO 0); --address to vga_ram
        display_on_in : IN STD_LOGIC                        --display time vga
    );
    END COMPONENT;

    COMPONENT accelerometer_controller
       PORT (
        clk_in         : IN STD_LOGIC;                       -- system clock
        rst_n_in       : IN STD_LOGIC;                       -- acktive low reset
        data_bus_out   : OUT STD_LOGIC_VECTOR (15 DOWNTO 0); -- instructions to acc 
        data_ram_out   : OUT STD_LOGIC_VECTOR (15 DOWNTO 0); -- saved data return
        data_ready_out : OUT STD_LOGIC;                      -- data processed spi processor continoue
        hold_main_in   : IN STD_LOGIC;                       -- hold porcessor
        rx_data_in : IN STD_LOGIC_VECTOR(15 DOWNTO 0));      -- z-axis acceleration data         
    END COMPONENT;

    --===========================================================================
    --                        Signals
    --===========================================================================
    SIGNAL rst_n_s        : STD_LOGIC;                      -- signal to hold synchornised reset  
    SIGNAL display_time_s : STD_LOGIC;                      -- signal to hold wether data to show on display or not
    SIGNAL we_b_s         : STD_LOGIC;                      -- write enable vga_ram
    SIGNAL data_b_s       : STD_LOGIC_VECTOR (2 DOWNTO 0);  -- data for vag_ram
    SIGNAL address_b_s    : STD_LOGIC_VECTOR (15 DOWNTO 0); --addres for vga_ram
    SIGNAL data_cpu_s     : STD_LOGIC_VECTOR (15 DOWNTO 0); --raw adxl data for grafic gen

    SIGNAL rx_s           : STD_LOGIC_VECTOR (15 DOWNTO 0); -- signal to hold z acceleration data
    SIGNAL data_bus_s     : STD_LOGIC_VECTOR (15 DOWNTO 0); -- Data instructions for ADXL345
    SIGNAL data_ready_s   : STD_LOGIC;                      -- proceed flag for spi_controller
    SIGNAL hold_main_s    : STD_LOGIC;                      -- hold main processor

BEGIN

    --===========================================================================
    --                        Instansiation
    --===========================================================================
    input_filter_inst : input_filter
    PORT MAP(
        clk50_in       => clk_50_in, -- system clock 50 MHz
        reset_n_in     => rst_n_in,  -- asynchrounus reset input
        reset_sync_out => rst_n_s   -- synchrounised reset output
    );

    vga_controller_inst : VGA_Controller
        PORT MAP(
        reset_n_in     => rst_n_s,       --reset input active low
        clk_50_in      => clk_50_in,     --system clock
        we_b_in        => we_b_s,        --write enable ram
        data_b_in      => data_b_s,      --data input ram
        adress_b_in    => address_b_s,   --addres input ram
        --VGA
        vga_vs_out     => vga_vs_out,
        vga_hs_out     => vga_hs_out,
        vga_r_out      => vga_r_out,
        vga_g_out      => vga_g_out,
        vga_b_out      => vga_b_out,
        display_on_out => display_time_s
    );

    grafic_inst : vga_grafic
    PORT MAP (
        clk50_in      => clk_50_in,     --system clock
        reset_n_in    => rst_n_s,       --reset active low
        data_cpu_in   => data_cpu_s,    --raw data input from accelerometer controller
        data_ready_in => data_ready_s,  -- reday signal from accelerometer controller
        --memory
        we_b_out      => we_b_s,        --we to vga_ram
        data_b_out    => data_b_s,      --data to vga ram
        adress_b_out  => address_b_s,   --address to vga_ram
        display_on_in => display_time_s --display time vga
    );
    
    spi_inst : spi_controller
    GENERIC MAP(
        clk_freq       => 50         --system clock frequency in MHz
        )   
    PORT MAP(
        clk_in         => clk_50_in,    --system clock
        rst_n_in       => rst_n_s,      --active low asynchronous reset
        data_bus_in    => data_bus_s,   -- instrcution adxl345
        miso           => miso_in,      --SPI bus: master in, slave out
        sclk           => sck_out,      --SPI bus: serial clock
        data_ready_in  => data_ready_s, -- proceed signal form main processor
        ss_n           => ss_out,       --SPI bus: slave select
        mosi           => mosi_out,     --SPI bus: master out, slave in
        hold_main_out  => hold_main_s,  -- hold main processor 
        rx_data_out    => rx_s);         --axis acceleration data
    
    acc_inst : accelerometer_controller
    PORT MAP(
        clk_in         => clk_50_in,    --system clock
        rst_n_in       => rst_n_s,      -- reset aktive low
        data_bus_out   => data_bus_s,   --instrction bus for adxl345
        data_ram_out   => data_cpu_s,   -- data output of RAM
        data_ready_out => data_ready_s, -- data processed spi processor continoue
        hold_main_in   => hold_main_s,  -- hold porcessor
        rx_data_in     => rx_s);         --axis acceleration data   
END rtl;