-- Quartus Prime VHDL Template
-- Single port RAM with single read/write address 

library ieee;
use ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.ALL;

--===========================================================================
--                        Define input/output ports
--===========================================================================
entity single_port_ram is
    generic (
        DATA_WIDTH : natural := 16;
        ADDR_WIDTH : natural := 12);
    port (
        clk     : in std_logic;
        addr    : IN STD_LOGIC_VECTOR((ADDR_WIDTH - 1) DOWNTO 0);
        data    : in std_logic_vector((DATA_WIDTH-1) downto 0);
        we      : in std_logic := '1';
        q       : out std_logic_vector((DATA_WIDTH -1) downto 0));
end entity;

architecture rtl of single_port_ram is

    -- Build a 2-D array type for the RAM
    subtype word_t is std_logic_vector((DATA_WIDTH-1) downto 0);
    type memory_t is array(2**ADDR_WIDTH-1 downto 0) of word_t;

    -- Declare the RAM signal.  Reset ram only for simulation
    signal ram : memory_t := (OTHERS => (OTHERS => '0'));

    -- Register to hold the address 
    signal addr_reg : STD_LOGIC_VECTOR((ADDR_WIDTH - 1) DOWNTO 0);

begin

    process(clk)
    begin
    if(rising_edge(clk)) then
        if(we = '1') then
           -- ram(addr) <= data;
            ram(conv_integer(addr)) <= data;
           
        end if;

        -- Register the address for reading
        addr_reg <= addr;
    end if;
    end process;

  --  q <= ram(to_integer(unsigned(addr_reg(2**ADDR_WIDTH - 1 downto 0))));
    q <= ram(conv_integer(addr_reg));

   

end rtl;
