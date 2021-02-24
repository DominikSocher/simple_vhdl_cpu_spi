-----------------------------------------------------------------------------
--Company: TEIS
--Engineer: Dominik Socher
--Created Date: Monday, February 1st 2021
-----------------------------------------------------------------------------
--File: c:\Users\Dominik\Documents\TEIS\VHDL_systemkurs\dominik_socher_vhdl2_ingenjorsjobb_a\design\vga_grafic.vhd
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
--   Simple state machine prints pixel in red/green/blue on screen to    
--   demonstrate function of adxl345     
--        
--        
----------------------------------------------------------------------------
--verified with the DE10-Lite board 
-----------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

--===========================================================================
--                        Define input/output ports
--===========================================================================
ENTITY vga_grafic IS
    PORT (
        clk50_in      : IN STD_LOGIC;
        reset_n_in    : IN STD_LOGIC;
        data_cpu_in   : IN STD_LOGIC_VECTOR (15 DOWNTO 0);
        data_ready_in : IN STD_LOGIC;
        --memory
        we_b_out      : OUT STD_LOGIC;
        data_b_out    : OUT STD_LOGIC_VECTOR (2 DOWNTO 0);
        adress_b_out  : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
        display_on_in : IN STD_LOGIC
    );
END ENTITY;

ARCHITECTURE rtl OF vga_grafic IS
--===========================================================================
--                        state machine 
--===========================================================================
    TYPE state_type IS (idle_state, clear_state, grafic_state, delay_state);
    --register to hold current state
    SIGNAL state_s          : state_type;
    --signal state_machine
--===========================================================================
--                        Signals
--===========================================================================
    SIGNAL pixel_count_s    : INTEGER RANGE 0 TO 19200; 
    SIGNAL x_pos_s          : UNSIGNED (15 DOWNTO 0); --register holds x axis value
    SIGNAL y_pos_s          : UNSIGNED (15 DOWNTO 0); --register holds x axis value
    SIGNAL z_pos_s          : UNSIGNED (15 DOWNTO 0); --register holds y axis value

BEGIN

--===========================================================================
--                   caluclate position for each axis     
--===========================================================================
    pos_calc: PROCESS (clk50_in, reset_n_in)
    BEGIN
        IF reset_n_in = '0' THEN
            x_pos_s <= (OTHERS => '0');
            y_pos_s <= (OTHERS => '0');
            z_pos_s <= (OTHERS => '0');
        ELSIF rising_edge(clk50_in) THEN
            x_pos_s <= to_unsigned( (160*(-to_integer(unsigned(data_cpu_in(15 downto 0))) +120)-1)+120-159, 16 );
            y_pos_s <= to_unsigned( (160*(-to_integer(unsigned(data_cpu_in(15 downto 0))) +120)-1)+160-159, 16 );
            z_pos_s <= to_unsigned( (160*(-to_integer(unsigned(data_cpu_in(15 downto 0))) +120)-1)+200-159, 16 );
        END IF;
    END PROCESS pos_calc;
--===========================================================================
--                        state machine
--===========================================================================   
    grafic_controller: PROCESS(clk50_in, reset_n_in)
        VARIABLE counter_v   : INTEGER RANGE 0 TO 50000;
    BEGIN
        IF reset_n_in = '0' THEN
            counter_v       := 0;
            pixel_count_s   <= 0;
            adress_b_out    <= (OTHERS => '0');
            data_b_out      <= (OTHERS => '0');
            we_b_out        <= '0';
            state_s         <= idle_state;           
        ELSIF rising_edge(clk50_in) THEN
            CASE state_s IS
                WHEN idle_state =>
                    IF data_ready_in = '1' THEN
                        state_s <= grafic_state;
                    ELSE
                        state_s <= idle_state;
                    END IF;
                --clear pixels    
                WHEN clear_state =>
                    IF (pixel_count_s = 19200) THEN 
                        we_b_out              <= '0';
                        pixel_count_s         <= 0;
                        state_s               <= grafic_state;
                    ELSE
                        we_b_out              <= '1';
                        data_b_out            <= (OTHERS => '0');
                        pixel_count_s         <= pixel_count_s + 1;
                        adress_b_out          <= STD_LOGIC_VECTOR(to_unsigned(pixel_count_s, adress_b_out'length));
                    END IF;
                --draw pixels
                WHEN grafic_state =>
                    IF (pixel_count_s = 19200) THEN 
                        we_b_out               <= '0';
                        pixel_count_s          <= 0;
                        state_s                <= clear_state;
                    ELSE
                        IF(display_on_in = '1') THEN
                            CASE pixel_count_s IS
                                WHEN 0 =>
                                    we_b_out      <= '1';
                                    pixel_count_s <= pixel_count_s + 1;
                                    adress_b_out  <= std_logic_vector(x_pos_s);
                                    data_b_out    <= "100";
                                    state_s       <= grafic_state;
                                WHEN 1 =>
                                    we_b_out      <= '1';
                                    pixel_count_s <= pixel_count_s + 1;
                                    adress_b_out  <= std_logic_vector(y_pos_s);
                                    data_b_out    <= "010";
                                    state_s       <= grafic_state;
                                WHEN 2 =>
                                    we_b_out      <= '1';
                                    pixel_count_s <= pixel_count_s + 1;
                                    adress_b_out  <= std_logic_vector(z_pos_s);
                                    data_b_out    <= "001";
                                    state_s       <= grafic_state;
                                WHEN OTHERS =>
                                    we_b_out  <= '0';
                                    state_s   <= delay_state;

                            END CASE;
                        END IF;
                    END IF;
                --delay next draw cyckel                  
                WHEN delay_state => 
                    IF counter_v < 50000 AND display_on_in = '0' THEN        
                        counter_v := counter_v + 1;
                        state_s    <= delay_state;
                    ELSE
                        counter_v := 0;
                        state_s    <= idle_state;
                    END IF;
                    adress_b_out   <= (OTHERS => '0');
                    data_b_out     <= (OTHERS => '0');
                    pixel_count_s <= 0;
            END CASE;     
        END IF;
    END PROCESS grafic_controller;
END rtl;