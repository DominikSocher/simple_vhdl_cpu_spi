-----------------------------------------------------------------------------
--Company: TEIS
--Engineer: Dominik Socher
--Created Date: Wednesday, November 25th 202020
-----------------------------------------------------------------------------
--File: input_filter.vhd
--Project: dominik_socher_vhdl_uppgift_2a
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
--        This is an input filter which filters digital input against meta
--        stability. It syncronices the input with two d-flip-flops.
--        
--        
-----------------------------------------------------------------------------
--In Signals:
--        clk50_in
--        reset_n_in
--Out Signals:
--        reset_sync_out
--        
-----------------------------------------------------------------------------
--verified with the DE10-Lite board 
-----------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY input_filter IS
    PORT (
        clk50_in : IN STD_LOGIC; --system clock
        reset_n_in : IN STD_LOGIC;
        reset_sync_out : OUT STD_LOGIC
    );

END ENTITY;

ARCHITECTURE rtl OF input_filter IS

    SIGNAL reset_t1, reset_t2 : STD_LOGIC; --reset sync

BEGIN

    reset_sync : PROCESS (clk50_in, reset_n_in) --sync reset witch two d-type-flip-flops
    BEGIN
        IF reset_n_in = '0' THEN
            reset_t1 <= '0';
            reset_t2 <= '0';
        ELSIF rising_edge(clk50_in) THEN
            reset_t1 <= '1';
            reset_t2 <= reset_t1;
        END IF;
    END PROCESS;

    reset_sync_out <= reset_t2;

END rtl;