-----------------------------------------------------------------------------
--Company: TEIS
--Engineer: Dominik Socher
--Created Date: Tuesday, January 12th 2021
-----------------------------------------------------------------------------
--File: c:\Users\Dominik\Documents\TEIS\VHDL_systemkurs\dominik_socher_vhdl2_ingenjorsjobb_a\design\accelerometer_controller.vhd
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
--   Main CPU     
--   Every cyckel start with the fetch state where the instruction data from rom 
--   gets split into cpu instructions and spi instructions.      
--   fetch -> decode -> execute 
--   Incomming data is getting stored in a RAM.    
--   
--   comment in state_cpu_s to see state transiton in modelsim.
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
ENTITY accelerometer_controller IS
    PORT (
        clk_in         : IN STD_LOGIC;                      -- system clock
        rst_n_in       : IN STD_LOGIC;                      -- reset aktive low
        data_bus_out   : OUT STD_LOGIC_VECTOR (15 DOWNTO 0); -- instructions to acc 
        data_ram_out   : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);-- saved data return
        data_ready_out : OUT STD_LOGIC;                     -- data processed spi processor continoue
        hold_main_in   : IN STD_LOGIC;                      -- hold porcessor
        rx_data_in     : IN STD_LOGIC_VECTOR(15 DOWNTO 0));  --axis acceleration data  
END accelerometer_controller;

ARCHITECTURE rtl OF accelerometer_controller IS
    --===========================================================================
    --                        state machine teis_cpu state
    --===========================================================================
    TYPE state_cpu_type IS (fetch1_state, fetch2_state, fetch3_state, fetch4_state, decode1_state, decode2_state, execute_nop_state,
                            execute_read_state, execute_write_state,  execute_jmp_state, 
                            execute_store_state, store1_state, store2_state);
    --register holds current state
    SIGNAL state_cpu_s : state_cpu_type := fetch1_state;
    --===========================================================================
    --                        SIGNALS CPU
    --===========================================================================   
    SIGNAL address_bus_s  : STD_LOGIC_VECTOR (7 DOWNTO 0);  --prgram counter rom
    SIGNAL pc_reg_s       : unsigned (7 DOWNTO 0);          --register to hold program counter
    SIGNAL ir_s           : STD_LOGIC_VECTOR (3 DOWNTO 0);  --instruction register
    SIGNAL dr_s           : STD_LOGIC_VECTOR (15 DOWNTO 0); --data register
    --SIGNAL cpu_state_s    : STD_LOGIC_VECTOR (1 DOWNTO 0);  --CPU state
    --test
    SIGNAL write_flag_s   : STD_LOGIC;                      -- ok signal to write DR 
    --===========================================================================
    --                        SIGNALS Memory
    --===========================================================================  
    SIGNAL data_out_s     : STD_LOGIC_VECTOR (19 DOWNTO 0); --data from ROM 
    SIGNAL addr_ram_s     : UNSIGNED (7 DOWNTO 0);          --addres bus RAM
    SIGNAL data_ram_s     : STD_LOGIC_VECTOR (15 DOWNTO 0);
    SIGNAL we_ram_s       : STD_LOGIC;
    --===========================================================================
    --                        Opcodes for TEIS cpu
    --===========================================================================  
    CONSTANT NOP_INST     : STD_LOGIC_VECTOR (3 DOWNTO 0) := x"0";
    CONSTANT WRITE_INST   : STD_LOGIC_VECTOR (3 DOWNTO 0) := x"1";
    CONSTANT READ_INST    : STD_LOGIC_VECTOR (3 DOWNTO 0) := x"2";
    CONSTANT STORE_INST   : STD_LOGIC_VECTOR (3 DOWNTO 0) := x"3";
    CONSTANT JMP_INST     : STD_LOGIC_VECTOR (3 DOWNTO 0) := x"4";
    --===========================================================================
    --                        Components
    --===========================================================================  
    COMPONENT single_port_rom IS
      generic (
         DATA_WIDTH : natural := 8;
         ADDR_WIDTH : natural := 8);
      port (
         clk    : in std_logic;
          addr  : in std_logic_vector(7 downto 0);
          q     : out std_logic_vector((DATA_WIDTH -1) downto 0));
    END COMPONENT single_port_rom;

    COMPONENT single_port_ram IS
        GENERIC (
            DATA_WIDTH : NATURAL := 16;
            ADDR_WIDTH : NATURAL := 12);
        PORT (
            clk  : IN STD_LOGIC;
            addr : IN STD_LOGIC_VECTOR((ADDR_WIDTH - 1) DOWNTO 0);
            data : IN STD_LOGIC_VECTOR((DATA_WIDTH - 1) DOWNTO 0);
            we   : IN STD_LOGIC := '1';
            q    : OUT STD_LOGIC_VECTOR((DATA_WIDTH - 1) DOWNTO 0));
    END COMPONENT single_port_ram;

BEGIN

--===========================================================================
--                        Instansiation
--===========================================================================  
    program_rom_inst : single_port_rom
    GENERIC MAP (
         DATA_WIDTH => 20,
         ADDR_WIDTH => 8)
    PORT MAP(
        clk  => clk_in,
        addr => address_bus_s,
        q    => data_out_s);

    ram_inst : single_port_ram
    GENERIC MAP (
        DATA_WIDTH => 16,
        ADDR_WIDTH => 8)
    PORT MAP(
        clk  => clk_in,
        addr => STD_LOGIC_VECTOR(addr_ram_s),
        data => data_ram_s,
        we   => we_ram_s,
        q    => data_ram_out);
    --===========================================================================
    --                        State machine main processor
    --===========================================================================  
    teis_cpu : PROCESS (clk_in, rst_n_in)
    BEGIN
        IF rst_n_in = '0' THEN
            state_cpu_s    <= fetch1_state;
            address_bus_s  <= (OTHERS => '0');
            pc_reg_s       <= (OTHERS => '0');
            ir_s           <= (OTHERS => '0');
            dr_s           <= (OTHERS => '0');
            addr_ram_s     <= (OTHERS => '0');
            data_ram_s     <= (OTHERS => '0');
            we_ram_s       <= '0';
            --cpu_state_s    <= "00";
            data_ready_out <= '0';
            write_flag_s   <= '0';
        ELSIF rising_edge(clk_in) THEN
            CASE state_cpu_s IS
            ---------fetch state
                WHEN fetch1_state =>
                    IF hold_main_in = '0' THEN
                        --cpu_state_s    <= "00";
                        address_bus_s  <= STD_LOGIC_VECTOR(pc_reg_s);
                        state_cpu_s    <= fetch2_state;
                    ELSE
                        state_cpu_s <= execute_nop_state;
                    END IF;
                WHEN fetch2_state =>
                    --cpu_state_s   <= "00";
                    write_flag_s   <= '0';
                    data_ready_out <= '0';
                    state_cpu_s   <= fetch3_state;
                --cpu instructions    
                WHEN fetch3_state =>
                    --cpu_state_s   <= "00";                    
                    ir_s          <= data_out_s(3 DOWNTO 0);
                    state_cpu_s   <= fetch4_state; 
                --adxl345 instructions   
                WHEN fetch4_state =>
                    --cpu_state_s   <= "00";
                    dr_s          <= data_out_s (19 DOWNTO 4);
                    state_cpu_s   <= decode1_state;
                WHEN decode1_state =>
                    pc_reg_s <= pc_reg_s + 1;
                    --cpu_state_s <= "01";  
                    state_cpu_s <= decode2_state;
                WHEN decode2_state =>
                    --cpu_state_s <= "01";  
                    CASE ir_s IS
                        WHEN NOP_INST =>
                            state_cpu_s <= execute_nop_state;
                        WHEN WRITE_INST =>
                            state_cpu_s <= execute_write_state;
                        WHEN READ_INST =>
                            state_cpu_s <= execute_read_state;
                        WHEN STORE_INST =>
                            state_cpu_s <= execute_store_state;
                        WHEN JMP_INST =>
                            state_cpu_s <= execute_jmp_state;
                        WHEN OTHERS =>
                            state_cpu_s <= fetch1_state;
                    END CASE;                   
            ---------exectue state
                WHEN execute_nop_state =>
                    --cpu_state_s <= "10";
                    state_cpu_s <= fetch1_state;
                    -- write data to spi device
                WHEN execute_write_state =>
                    --cpu_state_s <= "10";
                    --write instructions to output
                    write_flag_s   <= '1';
                    data_ready_out <= '1';
                    state_cpu_s    <= fetch1_state;
                    ----read data from spi device
                WHEN execute_read_state =>
                    --cpu_state_s <= "10";
                    data_ram_s  <= rx_data_in;
                    state_cpu_s <= fetch1_state;
                    --  store spi data to RAM
                WHEN execute_store_state =>
                   --cpu_state_s <= "10";
                    state_cpu_s <= store1_state;               
                WHEN execute_jmp_state =>
                   -- cpu_state_s <= "10";
                    --jmp to register addres 6
                    pc_reg_s <= x"06";
                    state_cpu_s <= fetch1_state;
            ---------store state
                WHEN store1_state =>
                    --cpu_state_s <= "11";
                    addr_ram_s  <= addr_ram_s + 1;
                    we_ram_s    <= '1';
                    state_cpu_s <= store2_state;
                WHEN store2_state =>
                    --cpu_state_s <= "11";
                    we_ram_s <= '0';
                    state_cpu_s <= fetch1_state;        
                WHEN OTHERS =>
                    state_cpu_s <= fetch1_state;
            END CASE;
        END IF;
    END PROCESS teis_cpu;
    --===========================================================================
    --                        data output
    --===========================================================================  
    data_bus_out <= dr_s WHEN write_flag_s = '1' ELSE (OTHERS => '0');

END rtl;