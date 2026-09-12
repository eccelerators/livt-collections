library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.livt_lang_icontext_package.all;

entity single_owner_edges is
    generic (CAPACITY: positive := 3);
end;
architecture test of single_owner_edges is
    signal clk: std_logic := '0';
    signal rst: std_logic := '1';
    signal context_value: t_icontext_in;
    signal clear_request, push_request, pop_request: boolean := false;
    signal push_accepted, pop_accepted: boolean;
    signal push_data, pop_data: std_logic_vector(7 downto 0) := x"00";
    signal item_count, free_space: signed(31 downto 0);
begin
    clk <= not clk after 5 ns;
    context_value <= (clk => clk, rst => rst,
        tickspersecond => to_unsigned(100000000, 32),
        periodns => to_unsigned(10, 32), hightimens => to_unsigned(5, 32),
        lowtimens => to_unsigned(5, 32));
    -- DUT_INSTANCES
    stimulus: process
        type memory_type is array (0 to CAPACITY - 1) of std_logic_vector(7 downto 0);
        variable memory: memory_type;
        variable head, tail, used, cycles: natural := 0;
        procedure cycle(clear_value, push_value, pop_value: boolean;
                        data_value: natural; reset_value: boolean := false) is
            variable take, put: boolean;
        begin
            wait until falling_edge(clk);
            clear_request <= clear_value;
            push_request <= push_value;
            pop_request <= pop_value;
            push_data <= std_logic_vector(to_unsigned(data_value mod 256, 8));
            if reset_value then rst <= '1'; else rst <= '0'; end if;
            take := not reset_value and not clear_value and pop_value and used > 0;
            put := not reset_value and not clear_value and push_value and (used < CAPACITY or take);
            wait for 1 ns;
            assert push_accepted = put report "push acceptance mismatch, cycle " & integer'image(cycles) severity failure;
            assert pop_accepted = take report "pop acceptance mismatch" severity failure;
            if take then
                assert pop_data = memory(head) report "wrong old-head data" severity failure;
            end if;
            wait until rising_edge(clk);
            if reset_value or clear_value then
                head := 0; tail := 0; used := 0;
            else
                if take then head := (head + 1) mod CAPACITY; end if;
                if put then
                    memory(tail) := std_logic_vector(to_unsigned(data_value mod 256, 8));
                    tail := (tail + 1) mod CAPACITY;
                end if;
                if put and not take then used := used + 1; end if;
                if take and not put then used := used - 1; end if;
            end if;
            wait for 1 ns;
            assert item_count = to_signed(used, 32)
                report "count not published at owner edge, cycle " & integer'image(cycles) severity failure;
            assert free_space = to_signed(CAPACITY - used, 32) report "space differs" severity failure;
			if used > 0 then
				assert pop_data = memory(head)
					report "stored data differs after edge, cycle " & integer'image(cycles)
						& ", expected=" & to_hstring(memory(head))
						& ", actual=" & to_hstring(pop_data)
					severity failure;
			end if;
            cycles := cycles + 1;
        end procedure;
    begin
        cycle(false, true, true, 0, true);
        cycle(false, false, true, 0);
        cycle(false, true, true, 17);
        cycle(false, false, true, 0);
        for index in 1 to CAPACITY loop cycle(false, true, false, index); end loop;
        cycle(false, true, false, 255);
        for index in 1 to 2 * CAPACITY loop cycle(false, true, true, index + 64); end loop;
        for index in 1 to CAPACITY loop cycle(false, false, true, 0); end loop;
        cycle(false, false, true, 0);
        for index in 0 to 255 loop
            cycle(index mod 31 = 0, index mod 3 /= 0, index mod 5 /= 0, index,
                  index mod 67 = 0);
        end loop;
        cycle(true, true, true, 12);
        cycle(false, true, false, 90);
        cycle(false, true, true, 33, true);
        cycle(false, true, false, 165);
        cycle(false, false, true, 0);
        report "SINGLE_OWNER_PASS capacity=" & integer'image(CAPACITY) & " cycles=" & integer'image(cycles);
        std.env.finish;
    end process;
    watchdog: process
    begin
        wait for 20 us;
        assert false report "watchdog" severity failure;
    end process;
end;
