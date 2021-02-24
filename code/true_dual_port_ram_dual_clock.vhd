-- Quartus Prime VHDL Template
-- True Dual-Port RAM with dual clock
--
-- Read-during-write on port A or B returns newly written data
-- 
-- Read-during-write on port A and B returns unknown data.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.ALL;
ENTITY true_dual_port_ram_dual_clock IS

    GENERIC (
        DATA_WIDTH : NATURAL := 8;
        ADDR_WIDTH : NATURAL := 6
    );

    PORT (
        clk_a : IN STD_LOGIC;
        clk_b : IN STD_LOGIC;
        addr_a : IN STD_LOGIC_VECTOR((ADDR_WIDTH - 1) DOWNTO 0);
        addr_b : IN STD_LOGIC_VECTOR((ADDR_WIDTH - 1) DOWNTO 0);
        data_a : IN STD_LOGIC_VECTOR((DATA_WIDTH - 1) DOWNTO 0);
        data_b : IN STD_LOGIC_VECTOR((DATA_WIDTH - 1) DOWNTO 0);
        we_a : IN STD_LOGIC := '1';
        we_b : IN STD_LOGIC := '1';
        q_a : OUT STD_LOGIC_VECTOR((DATA_WIDTH - 1) DOWNTO 0);
        q_b : OUT STD_LOGIC_VECTOR((DATA_WIDTH - 1) DOWNTO 0)
    );

END true_dual_port_ram_dual_clock;

ARCHITECTURE rtl OF true_dual_port_ram_dual_clock IS

    -- Build a 2-D array type for the RAM
    SUBTYPE word_t IS STD_LOGIC_VECTOR((DATA_WIDTH - 1) DOWNTO 0);
    TYPE memory_t IS ARRAY(2 ** ADDR_WIDTH - 1 DOWNTO 0) OF word_t;

    -- Declare the RAM 
    SHARED VARIABLE ram : memory_t;

BEGIN

    -- Port A
    PROCESS (clk_a)
    BEGIN
        IF (rising_edge(clk_a)) THEN
            IF (we_a = '1') THEN
                ram(conv_integer(addr_a)) := data_a;
            END IF;
            q_a <= ram(conv_integer(addr_a));
        END IF;
    END PROCESS;

    -- Port B
    PROCESS (clk_b)
    BEGIN
        IF (rising_edge(clk_b)) THEN
            IF (we_b = '1') THEN
                ram(conv_integer(addr_b)) := data_b;
            END IF;
            q_b <= ram(conv_integer(addr_b));
        END IF;
    END PROCESS;
END rtl;