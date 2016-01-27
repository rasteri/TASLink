----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    19:51:55 01/19/2016 
-- Design Name: 
-- Module Name:    main - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity main is
    Port ( CLK : in std_logic;
           RX : in std_logic;
           TX : out std_logic;
           btn : in  STD_LOGIC_VECTOR (3 downto 0);
           nes_latch : in  STD_LOGIC;
           nes_clk : in  STD_LOGIC;
           nes_dout : out STD_LOGIC;
           p2_latch : in std_logic;
           p2_clock : in std_logic;
           p2_dout : out std_logic;
           debug : out STD_LOGIC_VECTOR (3 downto 0);
           l: out STD_LOGIC_VECTOR(3 downto 0));
end main;

architecture Behavioral of main is
  component shift_register is
    Port ( latch : in  STD_LOGIC;
           clock : in  STD_LOGIC;
           din : in  STD_LOGIC_VECTOR (7 downto 0);
           dout : out  STD_LOGIC);
  end component;
  
  component shift_register2 is
    Port ( latch : in  STD_LOGIC;
           clock : in  STD_LOGIC;
           din : in  STD_LOGIC_VECTOR (7 downto 0);
           dout : out  STD_LOGIC;
           clk : in std_logic);
  end component;
  
  component filter is
    Port ( signal_in : in  STD_LOGIC;
           clk : in  STD_LOGIC;
           signal_out : out  STD_LOGIC);
  end component;
  
  component toggle is
    Port ( signal_in : in  STD_LOGIC;
           signal_out : out  STD_LOGIC);
  end component;
  
  component UART is
    Port ( rx_data_out : out STD_LOGIC_VECTOR (7 downto 0);
           rx_data_was_recieved : in STD_LOGIC;
           rx_byte_waiting : out STD_LOGIC;
           clk : in  STD_LOGIC;

           rx_in : in STD_LOGIC;
           tx_data_in : in STD_LOGIC_VECTOR (7 downto 0);
           tx_buffer_full : out STD_LOGIC;
           tx_write : in STD_LOGIC;
           tx_out : out STD_LOGIC);
  end component;

  signal button_data : std_logic_vector(7 downto 0) := "11111111";
  signal p2_button_data : std_logic_vector(7 downto 0) := "11111111";

  signal nes_clk_f : std_logic;
  signal nes_latch_f : std_logic;
  
  signal p2_clk_f : std_logic;
  signal p2_latch_f : std_logic;
  
  signal nes_clk_toggle : std_logic;
  signal nes_latch_toggle : std_logic;
  signal nes_clk_toggle_f : std_logic;
  signal nes_latch_toggle_f : std_logic;
  
  signal data_from_uart : STD_LOGIC_VECTOR (7 downto 0);
  signal uart_data_recieved : STD_LOGIC := '0';
	signal uart_byte_waiting : STD_LOGIC := '0';
  
  signal data_to_uart : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
	signal uart_buffer_full : STD_LOGIC;
	signal uart_write : STD_LOGIC := '0';
  
  signal uart_buffer_ptr : integer range 0 to 2 := 0;
  
  type BUTTON_DATA_buffer is array(0 to 31) of std_logic_vector(15 downto 0);
  
  signal button_queue : BUTTON_DATA_BUFFER;
  
  signal buffer_tail : integer range 0 to 31 := 0;
  signal buffer_head : integer range 0 to 31 := 0;
  
  signal test_toggle : std_logic := '0';
  
  signal prev_latch : std_logic := '0';
  
  signal frame_timer_active : std_logic := '0';
  signal frame_timer : integer range 0 to 160000 := 0;
  
  signal windowed_mode : std_logic := '0';
  
  signal uart_data_temp : std_logic_vector(7 downto 0);
begin

--  sr: shift_register port map (latch => nes_latch_f,
--                               clock => nes_clk_f,
--                               din => button_data,
--                               dout => nes_dout);
                               
  sr: shift_register2 port map (latch => nes_latch_f,
                               clock => nes_clk_f,
                               din => button_data,
                               dout => nes_dout,
                               clk => clk);
                               
--  p2_sr: shift_register port map (latch => nes_latch_f,
--                                  clock => p2_clk_f,
--                                  din => p2_button_data,
--                                  dout => p2_dout);
                                  
  p2_sr: shift_register2 port map (latch => nes_latch_f,
                                  clock => p2_clk_f,
                                  din => p2_button_data,
                                  dout => p2_dout,
                                  clk => clk);
                               
  latch_filter: filter port map (signal_in => nes_latch,
                                 clk => CLK,
                                 signal_out => nes_latch_f);
                                 
  clock_filter: filter port map (signal_in => nes_clk,
                                 clk => CLK,
                                 signal_out => nes_clk_f);
                                 
  p2_latch_filter: filter port map (signal_in => p2_latch,
                                    clk => CLK,
                                    signal_out => p2_latch_f);
                                 
  p2_clock_filter: filter port map (signal_in => p2_clock,
                                    clk => CLK,
                                    signal_out => p2_clk_f);
                                 
  button_data <= button_queue(buffer_tail)(7 downto 0) when buffer_head /= buffer_tail else
                 button_queue(31)(7 downto 0) when buffer_tail = 0 else
                 button_queue(buffer_tail-1)(7 downto 0);

  p2_button_data <= button_queue(buffer_tail)(15 downto 8) when buffer_head /= buffer_tail else
                    button_queue(31)(15 downto 8) when buffer_tail = 0 else
                    button_queue(buffer_tail-1)(15 downto 8);
                 
  --button_data <= not(btn) & "1111"; 
  
  --button_data <= btn(2) & "1111111" when btn(3) = '1' else
  --               "11111111";
  
  
  latch_toggle: toggle port map (signal_in => nes_latch,
                                 signal_out => nes_latch_toggle);
  
  latch_f_toggle: toggle port map (signal_in => nes_latch_f,
                                   signal_out => nes_latch_toggle_f);
  
  clk_toggle: toggle port map (signal_in => nes_clk,
                               signal_out => nes_clk_toggle);
  
  clk_f_toggle: toggle port map (signal_in => nes_clk_f,
                                 signal_out => nes_clk_toggle_f);
                                 
  uart1: UART port map (rx_data_out => data_from_uart,
                        rx_data_was_recieved => uart_data_recieved,
                        rx_byte_waiting => uart_byte_waiting,
                        clk => CLK,
                        rx_in => RX,
                        tx_data_in => data_to_uart,
                        tx_buffer_full => uart_buffer_full,
                        tx_write => uart_write,
                        tx_out => TX);
  
uart_recieve_btye: process(CLK)
	begin
		if (rising_edge(CLK)) then
			if (uart_byte_waiting = '1' and uart_data_recieved = '0') then
        test_toggle <= not(test_toggle);
        case uart_buffer_ptr is
          when 0 =>
            case data_from_uart is
              when x"66" => -- 'f'
                
                uart_buffer_ptr <= 1;
              
              when x"63" => -- 'c'
                buffer_head <= buffer_tail;
                
                uart_buffer_ptr <= 0;  
              
              when x"77" => -- 'w'
                windowed_mode <= '1';
                
              when x"6C" => -- 'l'
                windowed_mode <= '0';
              
              when others =>
              
            end case;
            
          when 1 =>
            if ((buffer_head = 31 and buffer_tail /= 0) or (buffer_head /= 31 and (buffer_head + 1) /= buffer_tail)) then
              -- add it to the next spot
              uart_data_temp <= data_from_uart;
            end if;
            
            uart_buffer_ptr <= 2;
              
          when 2 =>
            if ((buffer_head = 31 and buffer_tail /= 0) or (buffer_head /= 31 and (buffer_head + 1) /= buffer_tail)) then
              -- add it to the next spot
              button_queue(buffer_head) <= data_from_uart & uart_data_temp;

              -- move
              if (buffer_head = 31) then
                buffer_head <= 0;
              else
                buffer_head <= buffer_head + 1;
              end if;
            end if;
            
            uart_buffer_ptr <= 0;
            
          when others =>
        end case;
      	uart_data_recieved <= '1';
			else
				uart_data_recieved <= '0';
			end if;
    end if;
	end process;
  
  process (clk) is
  begin
    if (rising_edge(clk)) then
      uart_write <= '0';
      
      if (windowed_mode = '1' and frame_timer_active = '1') then
        if (frame_timer = 96000) then
          frame_timer <= 0;
          frame_timer_active <= '0';
        
          -- move tail pointer if possible
          if (buffer_tail /= buffer_head) then
            if (buffer_tail = 31) then
              buffer_tail <= 0;
            else
              buffer_tail <= buffer_tail + 1;
            end if;
          end if;
          
          -- Send feedback that a frame was consumed
          if (uart_buffer_full = '0') then
            uart_write <= '1';
            data_to_uart <= x"66";
          end if;
          
        else
          frame_timer <= frame_timer + 1;
        end if;
      end if;

      if (nes_latch_f /= prev_latch) then
        if (nes_latch_f = '1') then
          if (windowed_mode = '1') then
            frame_timer <= 0;
            frame_timer_active <= '1';
          else
            -- move tail pointer if possible
            if (buffer_tail /= buffer_head) then
              if (buffer_tail = 31) then
                buffer_tail <= 0;
              else
                buffer_tail <= buffer_tail + 1;
              end if;
            end if;
            
            -- Send feedback that a frame was consumed
            if (uart_buffer_full = '0') then
              uart_write <= '1';
              data_to_uart <= x"66";
            end if;
          end if;
        end if;
        prev_latch <= nes_latch_f;
      end if;
    end if;
  end process;


  l <= std_logic_vector(to_unsigned(buffer_tail, 4));
    
  debug(0) <= nes_latch_toggle;
  debug(1) <= p2_latch_f;
  debug(2) <= nes_clk_toggle;
  debug(3) <= p2_clk_f;

end Behavioral;
