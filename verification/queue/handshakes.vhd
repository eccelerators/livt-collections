library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.livt_lang_icontext_package.all;
use work.livt_collections_QUEUE_INTERFACE_package.all;

entity queue_handshakes is end;
architecture test of queue_handshakes is
    signal clk: std_logic := '0';
    signal rst: std_logic := '1';
    signal context_value: t_icontext_in;
    signal enqueue_in: t_QUEUE_INTERFACE_tryenqueue_in := (value => x"00", run => '0');
    signal enqueue_out: t_QUEUE_INTERFACE_tryenqueue_out;
    signal dequeue_in: t_QUEUE_INTERFACE_trydequeue_in := (run => '0');
    signal dequeue_out: t_QUEUE_INTERFACE_trydequeue_out;
    signal clear_in: t_QUEUE_INTERFACE_clear_in := (run => '0');
    signal clear_out: t_QUEUE_INTERFACE_clear_out;
    signal count_in: t_QUEUE_INTERFACE_getcount_in := (run => '0');
    signal count_out: t_QUEUE_INTERFACE_getcount_out;
    signal space_in: t_QUEUE_INTERFACE_getspace_in := (run => '0');
    signal space_out: t_QUEUE_INTERFACE_getspace_out;
begin
    clk <= not clk after 5 ns;
    context_value <= (clk => clk, rst => rst,
        tickspersecond => to_unsigned(100000000, 32),
        periodns => to_unsigned(10, 32), hightimens => to_unsigned(5, 32),
        lowtimens => to_unsigned(5, 32));
    dut: entity work.livt_collections_queue8 port map (
        ctor_lvt_context_in => context_value,
        tryenqueue_in => enqueue_in, tryenqueue_out => enqueue_out,
        trydequeue_in => dequeue_in, trydequeue_out => dequeue_out,
        clear_in => clear_in, clear_out => clear_out,
        getcount_in => count_in, getcount_out => count_out,
        getspace_in => space_in, getspace_out => space_out);
    stimulus: process
        procedure tick is
        begin
            wait until rising_edge(clk);
            wait for 1 ns;
        end;
        procedure reset_queue is
        begin
            wait until falling_edge(clk);
            rst <= '1';
            enqueue_in.run <= '0';
            dequeue_in.run <= '0';
            clear_in.run <= '0';
            count_in.run <= '0';
            space_in.run <= '0';
            tick;
            tick;
            assert enqueue_out.busy = '0' and dequeue_out.busy = '0'
                and clear_out.busy = '0' report "reset did not release calls" severity failure;
            wait until falling_edge(clk);
            rst <= '0';
            tick;
        end;
        procedure call_method(signal run: out std_logic; signal busy: in std_logic;
                              label_text: string; measure: boolean := false) is
            variable seen_busy: boolean := false;
        begin
            wait until falling_edge(clk);
            run <= '1';
            for cycles in 1 to 64 loop
                tick;
                run <= '0';
                if busy = '1' then seen_busy := true; end if;
                if seen_busy and busy = '0' then
                    if measure then
                        report "MEASURE " & label_text & " cycles=" & integer'image(cycles);
                    end if;
                    return;
                end if;
            end loop;
            assert false report "bounded completion failed: " & label_text severity failure;
        end;
    begin
        reset_queue;
        call_method(clear_in.run, clear_out.busy, "clear", true);
        call_method(count_in.run, count_out.busy, "count", true);
        assert count_out.return_value = 0 severity failure;
        call_method(space_in.run, space_out.busy, "space", true);
        assert space_out.return_value = 8 severity failure;
        enqueue_in.value <= x"A5";
        call_method(enqueue_in.run, enqueue_out.busy, "enqueue", true);
        assert enqueue_out.return_value severity failure;
        call_method(dequeue_in.run, dequeue_out.busy, "dequeue", true);
        assert dequeue_out.return_value and dequeue_out.value = x"A5" severity failure;
        call_method(dequeue_in.run, dequeue_out.busy, "empty_dequeue", true);
        assert not dequeue_out.return_value and dequeue_out.value = x"00" severity failure;
        for index in 0 to 7 loop
            enqueue_in.value <= std_logic_vector(to_unsigned(index, 8));
            call_method(enqueue_in.run, enqueue_out.busy, "fill");
            assert enqueue_out.return_value severity failure;
        end loop;
        call_method(enqueue_in.run, enqueue_out.busy, "full_enqueue", true);
        assert not enqueue_out.return_value severity failure;
        call_method(clear_in.run, clear_out.busy, "full_clear", true);

        -- Sweep reset across every phase of enqueue, dequeue and clear calls.
        for operation in 0 to 2 loop
            for offset in 0 to 24 loop
                reset_queue;
                enqueue_in.value <= x"3C";
                call_method(enqueue_in.run, enqueue_out.busy, "seed");
                wait until falling_edge(clk);
                if operation = 0 then enqueue_in.run <= '1';
                elsif operation = 1 then dequeue_in.run <= '1';
                else clear_in.run <= '1'; end if;
                for phase in 1 to offset loop
                    tick;
                    enqueue_in.run <= '0';
                    dequeue_in.run <= '0';
                    clear_in.run <= '0';
                end loop;
                reset_queue;
                for settle in 1 to 30 loop tick; end loop;
                call_method(count_in.run, count_out.busy, "reset_count");
                assert count_out.return_value = 0 report "stale operation after reset" severity failure;
                call_method(space_in.run, space_out.busy, "reset_space");
                assert space_out.return_value = 8 severity failure;
                enqueue_in.value <= x"5A";
                call_method(enqueue_in.run, enqueue_out.busy, "recovery_enqueue");
                assert enqueue_out.return_value severity failure;
                call_method(dequeue_in.run, dequeue_out.busy, "recovery_dequeue");
                assert dequeue_out.return_value and dequeue_out.value = x"5A"
                    report "reset recovery lost data" severity failure;
            end loop;
        end loop;
        report "QUEUE_HANDSHAKE_PASS reset_offsets=75";
        std.env.finish;
    end process;
    watchdog: process
    begin
        wait for 200 us;
        assert false report "watchdog" severity failure;
    end process;
end;
