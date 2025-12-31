module top_tb
(
    input   logic   clk,
    input   logic   rst
);

    longint timeout;
    longint total_miss_cycles;
    longint total_resp_cycles;
    longint total_store_cycles;
    longint total_stores;
    longint total_load_cycles;
    longint total_loads;
    
    initial begin
        $value$plusargs("TIMEOUT_ECE411=%d", timeout);
        total_miss_cycles = '0;
        total_resp_cycles = '0;
        total_store_cycles = '0;
        total_stores = '0;
        total_load_cycles = '0;
        total_loads = '0;
    end

    mem_itf_banked mem_itf(.*);
    dram_w_burst_frfcfs_controller mem(.itf(mem_itf));

    mon_itf #(.CHANNELS(8)) mon_itf(.*);
    monitor #(.CHANNELS(8)) monitor(.itf(mon_itf));

    cpu dut(
        .clk            (clk),
        .rst            (rst),

        .bmem_addr  (mem_itf.addr  ),
        .bmem_read  (mem_itf.read  ),
        .bmem_write (mem_itf.write ),
        .bmem_wdata (mem_itf.wdata ),
        .bmem_ready (mem_itf.ready ),
        .bmem_raddr (mem_itf.raddr ),
        .bmem_rdata (mem_itf.rdata ),
        .bmem_rvalid(mem_itf.rvalid)
    );


    `include "rvfi_reference.svh"

    initial begin
        `ifdef ECE411_FST_DUMP
            $dumpfile("dump.fst");
        `endif
        `ifdef ECE411_VCD_DUMP
            $dumpfile("dump.vcd");
        `endif
        $dumpvars();
        if ($test$plusargs("NO_DUMP_ALL_ECE411")) begin
            $dumpvars(0, dut);
            $dumpoff();
        end else begin
            $dumpvars();
        end
    end

    final begin
        $dumpflush;
    end

    always @(posedge clk) begin
        for (int unsigned i = 0; i < 8; ++i) begin
            if (mon_itf.halt[i]) begin
                $display("Total cycles in cache miss state: ", total_miss_cycles);
                $display("Total cache misses: ", total_resp_cycles);
                $display("Average cycles per miss: ", real'(total_miss_cycles) / real'(total_resp_cycles));
                $display("Total cycles executing store: ", total_store_cycles);
                $display("Total stores: ", total_stores);
                $display("Average cycles per store: ", real'(total_store_cycles) / real'(total_stores));
                $display("Total cycles executing loads: ", total_load_cycles);
                $display("Total loads: ", total_loads);
                $display("Average cycles per load: ", real'(total_load_cycles) / real'(total_loads));
                $display("Average cycles per load/store: ", real'(total_load_cycles + total_store_cycles) / real'(total_loads + total_stores));
                $finish;
            end
        end
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $fatal;
        end
        if (mon_itf.error != 0) begin
            $fatal;
        end
        if (mem_itf.error != 0) begin
            $fatal;
        end
        timeout <= timeout - 1;
        if(dut.icache_dfp_resp) begin
            total_resp_cycles <= total_resp_cycles + 1;
            total_miss_cycles <= total_miss_cycles + 1;
        end else if(dut.icache_dfp_read) begin
            total_miss_cycles <= total_miss_cycles + 1;
        end
        if(dut.load_store_queue_i.elemcount >= 1 && dut.load_store_queue_i.dout[0].ready && dut.load_store_queue_i.dout[0].is_load) begin
            total_load_cycles <= total_load_cycles + 1;
            if(dut.load_store_logic_i.cdb.ready) begin
                total_loads <= total_loads + 1;
            end
        end
        if(dut.load_store_queue_i.elemcount >= 1 && dut.load_store_queue_i.dout[0].ready && !dut.load_store_queue_i.dout[0].is_load) begin
            total_store_cycles <= total_store_cycles + 1;
            if(dut.load_store_logic_i.store_done) begin
                total_stores <= total_stores + 1;
            end
        end
    end

endmodule
