-----------------------------------------------------------------------------
--Company: TEIS
--Engineer: Dominik Socher
--Created Date: Friday, January 15th 2021
-----------------------------------------------------------------------------
--File: c:\Users\Dominik\Documents\TEIS\VHDL_systemkurs\dominik_socher_vhdl2_ingenjorsjobb_a\design\spi_controller.vhd
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
--10.02.21      DS     Changed sclk and ss_n to OUT
-----------------------------------------------------------------------------
--Description:
--    State machine controls data flow to spi_master and pauses main cpu    
--    to NOP when no valid data.
--    State machin  sends data to spi_master    
--    State machine receives data from spi_master            
-----------------------------------------------------------------------------
--verified with the DE10-Lite board 
-----------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

--===========================================================================
--                        Define input/output ports
--===========================================================================
ENTITY spi_controller IS
    GENERIC (
       clk_freq       : INTEGER := 50);                       --system clock frequency in MHz
    PORT (
        clk_in           : IN STD_LOGIC;                        --system clock
        rst_n_in         : IN STD_LOGIC;                        --active low reset
        data_bus_in      : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);    -- instrcution adxl345
        miso             : IN STD_LOGIC;                        --SPI bus: master in, slave out
        data_ready_in    : IN STD_LOGIC;                        -- proceed signal form main processor
        sclk             : OUT STD_LOGIC;                    --SPI bus: serial clock
        ss_n             : OUT STD_LOGIC_VECTOR(0 DOWNTO 0); --SPI bus: slave select
        mosi             : OUT STD_LOGIC;                       --SPI bus: master out, slave in
        hold_main_out    : OUT STD_LOGIC;                       -- hold main processor                      
        rx_data_out      : OUT STD_LOGIC_VECTOR(15 DOWNTO 0));  --received data out
END spi_controller;

ARCHITECTURE rtl OF spi_controller IS
    --===========================================================================
    --                        state machine co_porcessor_spi
    --===========================================================================
    TYPE state_spi_type IS (idle_state, tx_state, rx_state, output_state, finish_state, break1_state, break2_state);
    --register holds current state
    SIGNAL state_spi_s : state_spi_type := idle_state;
    --===========================================================================
    --                        SIGNALS 
    --===========================================================================   
    SIGNAL spi_busy_s        : STD_LOGIC;                     -- busy signal from SPI component
    SIGNAL spi_ena_s         : STD_LOGIC;                     -- enable for SPI component
    SIGNAL spi_cont_s        : STD_LOGIC;                     -- continuous mode signal for SPI component
    SIGNAL spi_rx_data_s     : STD_LOGIC_VECTOR(15 DOWNTO 0);  -- receive data form SPI component
    SIGNAL spi_tx_data_s     : STD_LOGIC_VECTOR(15 DOWNTO 0);  -- transmit data to SPI component
    SIGNAL start_up_s        : STD_LOGIC;                     -- startup dealy signal
    
    SIGNAL rx_buffer_s       : STD_LOGIC_VECTOR (15 DOWNTO 0); -- register hold acc data x

    --===========================================================================
    --                        Components
    --===========================================================================  
    COMPONENT spi_master IS
        GENERIC (
            slaves  : INTEGER := 1;                                 --number of spi slaves
            d_width : INTEGER := 8);                                --data bus width
        PORT (
            clock   : IN STD_LOGIC;                                 --system clock
            reset_n : IN STD_LOGIC;                                 --active low reset
            enable  : IN STD_LOGIC;                                 --initiate transaction
            cpol    : IN STD_LOGIC;                                 --spi clock polarity
            cpha    : IN STD_LOGIC;                                 --spi clock phase
            cont    : IN STD_LOGIC;                                 --continuous mode command
            clk_div : IN INTEGER;                                   --system clock cycles per 1/2 period of sclk
            addr    : IN INTEGER;                                   --address of slave
            tx_data : IN STD_LOGIC_VECTOR(d_width - 1 DOWNTO 0);    --data to transmit
            miso    : IN STD_LOGIC;                                 --master in, slave out
            sclk    : BUFFER STD_LOGIC;                             --spi clock
            ss_n    : BUFFER STD_LOGIC_VECTOR(slaves - 1 DOWNTO 0); --slave select
            mosi    : OUT STD_LOGIC;                                --master out, slave in
            busy    : OUT STD_LOGIC;                                --busy / data ready signal
            rx_data : OUT STD_LOGIC_VECTOR(d_width - 1 DOWNTO 0));  --data received
        END COMPONENT spi_master;

    BEGIN

    --===========================================================================
    --                        Instansiation
    --===========================================================================  
        spi_master_0 : spi_master
        GENERIC MAP(
            slaves  => 1,  --number of spi slaves
            d_width => 16)  --data bus width
        PORT MAP(
            clock   => clk_in,         -- system clock
            reset_n => rst_n_in,       -- reset active low
            enable  => spi_ena_s,      --initiate transaction
            cpol    => '1',            -- SPI clock polarity
            cpha    => '1',            -- SPI clock phase
            cont    => spi_cont_s,     -- SPI continuous mode 
            clk_div => clk_freq/10,    --system clock cycles per 1/2 period of sclk
            addr    => 0,              --address of slave
            tx_data => spi_tx_data_s,  --data to transmit
            miso    => miso,           -- SPI master in slave out
            sclk    => sclk,           -- SPI serial clock
            ss_n    => ss_n,           -- spi slave select
            mosi    => mosi,           -- SPI master out slvae in
            busy    => spi_busy_s,     --busy / data ready signal
            rx_data => spi_rx_data_s); --data received
    --===========================================================================
    --                        State machine co_porcessor_spi
    --===========================================================================  
            co_porcessor_spi: PROCESS(clk_in, rst_n_in)
                VARIABLE counter1_v   : INTEGER RANGE 0 TO clk_freq;
                VARIABLE counter2_v   : INTEGER RANGE 0 TO 3;
            BEGIN
                IF rst_n_in = '0' THEN
                    state_spi_s       <= idle_state;
                    counter1_v         := 0;
                    counter2_v         := 0;
                    spi_ena_s         <= '0';
                    spi_cont_s        <= '0';
                    hold_main_out     <= '1'; -- stall main direct after reset
                    start_up_s        <= '1';
                    spi_tx_data_s     <= (OTHERS => '0');
                    rx_data_out       <= (OTHERS => '0');   
                    rx_buffer_s       <= (OTHERS => '0'); 
                ELSIF rising_edge(clk_in) THEN
                    CASE state_spi_s IS
                --------IDLE STATE
                        WHEN idle_state =>
                            --startup delay 200 ns
                            IF start_up_s = '1' THEN
                                IF counter1_v < clk_freq/2 THEN        
                                    counter1_v    := counter1_v + 1;
                                ELSE
                                    counter1_v := 0;
                                    start_up_s    <= '0';
                                    hold_main_out <= '0';
                                END IF;
                            ELSE 
                                IF data_ready_in = '1' THEN
                                    state_spi_s <= tx_state;
                                    spi_ena_s   <= '0';
                                    spi_cont_s  <= '0';
                                ELSE 
                                    state_spi_s <= idle_state;
                                END IF;

                            END IF;
                --------TRANSMIT STATE
                        WHEN tx_state =>
                            spi_ena_s     <= '1';
                            spi_cont_s    <= '1';
                            hold_main_out <= '1';
                            --transmit data to adxl345
                            IF spi_busy_s = '0' THEN
                                hold_main_out <= '1';
                                spi_tx_data_s <= data_bus_in;
                                state_spi_s   <= break1_state;
                            ELSE 
                                state_spi_s   <=  tx_state;
                            END IF;   
                --------BREAK  
                        --wait 200 ns to fullfill spi timing requierment          
                        WHEN break1_state =>
                            spi_ena_s    <= '0';
                            spi_cont_s   <= '0';
                            IF counter1_v < clk_freq/2 THEN        
                                counter1_v   := counter1_v + 1;
                                state_spi_s  <= break1_state;
                            ELSE
                                counter1_v   := 0;
                                IF spi_busy_s = '0' THEN
                                    state_spi_s <= rx_state;
                                END IF;
                            END IF;
                --------RECEIVE STATE
                        WHEN rx_state =>
                            spi_ena_s    <= '1';
                            spi_cont_s   <= '1';
                            IF spi_busy_s = '0' THEN
                                counter2_v := counter2_v + 1;
                                CASE counter2_v IS
                                    WHEN 1 =>
                                        --receive low byte
                                        rx_buffer_s(7 DOWNTO 0) <= spi_rx_data_s(7 DOWNTO 0);
                                        state_spi_s <= finish_state;
                                    WHEN 2 =>
                                        --receive high byte
                                        rx_buffer_s(15 DOWNTO 8) <= spi_rx_data_s(15 DOWNTO 8);
                                        counter2_v := 0;
                                        state_spi_s <= output_state;
                                    WHEN OTHERS =>
                                        NULL;
                                END CASE;
                            END IF;
                --------Output data           
                        WHEN output_state =>
                            rx_data_out <= rx_buffer_s;
                            state_spi_s <= finish_state;
                --------FINISED 
                        --finished one complete data transmission
                        WHEN finish_state =>
                            spi_ena_s    <= '0';
                            spi_cont_s   <= '0';    
                            IF spi_busy_s = '0' THEN
                               state_spi_s <= break2_state;             
                            ELSE 
                                state_spi_s <= finish_state;
                            END IF;
                        WHEN break2_state =>
                        --delays next idle state at least 200 ns
                            IF counter1_v < clk_freq/2 THEN        
                                counter1_v   := counter1_v + 1;
                                state_spi_s  <= break2_state;
                            ELSE
                                counter1_v  := 0;
                                state_spi_s <= idle_state;
                                IF spi_busy_s = '0' THEN
                                    hold_main_out <= '0';
                                ELSE
                                    state_spi_s <= break2_state;
                                END IF;
                            END IF;                                                         
                        WHEN OTHERS =>          
                            NULL; -- do nothing
                    END CASE;               
                END IF;
            END PROCESS co_porcessor_spi;
    END rtl;