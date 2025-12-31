module top_tb;
    //---------------------------------------------------------------------------------
    // Waveform generation.
    //---------------------------------------------------------------------------------
    // initial begin
    //     $fsdbDumpfile("dump.fsdb");
    //     $fsdbDumpvars(0, "+all");
    // end

    //---------------------------------------------------------------------------------
    // TODO: Declare cache port signals:
    //---------------------------------------------------------------------------------


    //---------------------------------------------------------------------------------
    // TODO: Generate a clock:
    //---------------------------------------------------------------------------------
    bit clk;
    initial clk = 1'b1;
    always #2ns clk = ~clk;

    //---------------------------------------------------------------------------------
    // TODO: Write a task to generate reset:
    //---------------------------------------------------------------------------------
    bit rst;
    int timeout = 1000000; // In cycles, change according to your needs

    //---------------------------------------------------------------------------------
    // TODO: Instantiate the DUT and physical memory:
    //---------------------------------------------------------------------------------
    mem_itf_w_mask  #(1, 32 ) ufp_mem_itf(.*);
    mem_itf_wo_mask #(1, 256) dfp_mem_itf(.*);
    simple_memory_256_wo_mask simple_memory(.itf(dfp_mem_itf));
    
    cache dut(
        .clk        (clk),
        .rst        (rst),
        // cpu side signals, uf -> upward facing port
        .ufp_addr   (ufp_mem_itf.addr [0]),
        .ufp_rmask  (ufp_mem_itf.rmask[0]),
        .ufp_wmask  (ufp_mem_itf.wmask[0]),
        .ufp_rdata  (ufp_mem_itf.rdata[0]),
        .ufp_wdata  (ufp_mem_itf.wdata[0]),
        .ufp_resp   (ufp_mem_itf.resp [0]),
        // memory side signals, dfp -> downward facing port
        .dfp_addr   (dfp_mem_itf.addr [0]),
        .dfp_read   (dfp_mem_itf.read [0]),
        .dfp_write  (dfp_mem_itf.write[0]),
        .dfp_rdata  (dfp_mem_itf.rdata[0]),
        .dfp_wdata  (dfp_mem_itf.wdata[0]),
        .dfp_resp   (dfp_mem_itf.resp [0])
    );

    //---------------------------------------------------------------------------------
    // TODO: Write tasks to test various functionalities:
    //---------------------------------------------------------------------------------
    task check_dfp_idle();
        if (dfp_mem_itf.addr[0] !== 'x) begin
            $error("dfp_addr is not don't cares!");
        end
        if (dfp_mem_itf.read[0] !== '0) begin
            $error("dfp_read is not 0!");
        end
        if (dfp_mem_itf.write[0] !== '0) begin
            $error("dfp_write is not 0!");
        end
        if (dfp_mem_itf.rdata[0] !== 'x) begin
            $error("dfp_rdata is not don't cares!");
        end
        if (dfp_mem_itf.wdata[0] !== 'x) begin
            $error("dfp_wdata is not don't cares!");
        end
        if (dfp_mem_itf.resp[0] !== '0) begin
            $error("dfp_resp is not 0!");
        end
    endtask

    task check_dfp_read();
        @ (negedge clk);
        while (~dfp_mem_itf.resp[0]) begin
            if (dfp_mem_itf.read[0] !== '1) begin
                $error("dfp_read is not 1!");
            end
            if (dfp_mem_itf.write[0] !== '0) begin
                $error("dfp_write is not 0!");
            end
            if (dfp_mem_itf.wdata[0] !== 'x) begin
                $error("dfp_wdata is not don't cares!");
            end
            @ (posedge clk);
            @ (negedge clk);
        end
        if (dfp_mem_itf.read[0] !== '1) begin
            $error("dfp_read is not 1!");
        end
        if (dfp_mem_itf.write[0] !== '0) begin
            $error("dfp_write is not 0!");
        end
        if (dfp_mem_itf.wdata[0] !== 'x) begin
            $error("dfp_wdata is not don't cares!");
        end
    endtask

    task check_dfp_write();
        @ (negedge clk);
        while (~dfp_mem_itf.resp[0]) begin
            if (dfp_mem_itf.read[0] !== '0) begin
                $error("dfp_read is not 0!");
            end
            if (dfp_mem_itf.write[0] !== '1) begin
                $error("dfp_write is not 1!");
            end
            if (dfp_mem_itf.rdata[0] !== 'x) begin
                $error("dfp_rdata is not don't cares!");
            end
            @ (posedge clk);
            @ (negedge clk);
        end
        if (dfp_mem_itf.read[0] !== '0) begin
            $error("dfp_read is not 0!");
        end
        if (dfp_mem_itf.write[0] !== '1) begin
            $error("dfp_write is not 1!");
        end
        if (dfp_mem_itf.rdata[0] !== 'x) begin
            $error("dfp_rdata is not don't cares!");
        end
    endtask
    
    task check_readout(
        input   logic   [31:0]  rdata_prev,
        input   logic   [3:0]   rmask_prev
    );
        check_dfp_idle(); // should've been idle
        if (rmask_prev[3] & rmask_prev[2] & rmask_prev[1] & rmask_prev[0] // rmask=0000 indicates nothing to check
            & ~ufp_mem_itf.resp[0]) begin
            $error("expected ufp response");
        end
        for (int i = 0; i < 4; i++) begin
            if (rmask_prev[i] && (ufp_mem_itf.rdata[0][8*i +: 8] !== rdata_prev[8*i +: 8])) begin
                $error("rdata byte %d mismatch", i);
            end
        end
    endtask

    task check_plru(
        input   logic   [3:0]   plru_set_prev,
        input   logic   [2:0]   plru_arr_prev
    );
        if (dut.plru_wcs !== 1'b0) begin
            $error("expected plru write chip select");
        end
        if (dut.plru_waddr !== plru_set_prev) begin
            $error("lru waddr mismatch!");
        end
        if (dut.plru_win !== plru_arr_prev) begin
            $error("lru wdata mismatch!");
        end
    endtask

    task clear_ufp_mem_itf();
        ufp_mem_itf.addr [0] <= 'x;
        ufp_mem_itf.rmask[0] <= '0;
        ufp_mem_itf.wmask[0] <= '0;
        ufp_mem_itf.wdata[0] <= 'x;
    endtask

    task setup_read_ufp_mem_itf(
        input   logic   [31:0]  addr,
        input   logic   [3:0]   rmask
    );
        ufp_mem_itf.addr [0] <= addr;
        ufp_mem_itf.rmask[0] <= rmask;
        ufp_mem_itf.wmask[0] <= '0;
        ufp_mem_itf.wdata[0] <= 'x;
    endtask

    task setup_write_ufp_mem_itf(
        input   logic   [31:0]  addr,
        input   logic   [3:0]   wmask,
        input   logic   [31:0]  wdata
    );
        ufp_mem_itf.addr [0] <= addr;
        ufp_mem_itf.rmask[0] <= '0;
        ufp_mem_itf.wmask[0] <= wmask;
        ufp_mem_itf.wdata[0] <= wdata;
    endtask
    
    task clobber_ufp_mem_itf();
        ufp_mem_itf.addr [0] <= 'x;
        ufp_mem_itf.rmask[0] <= 'x;
        ufp_mem_itf.wmask[0] <= 'x;
        ufp_mem_itf.wdata[0] <= 'x;
    endtask

    task stall_write_hit(
        input   logic           stall
    );
        if (stall) begin
            clobber_ufp_mem_itf();
            @ (posedge clk);
            check_dfp_idle(); // no dfp operations when stalled
        end
    endtask

    task read_hit(
        input   logic   [31:0]  addr,
        input   logic   [3:0]   rmask,
        input   logic           stall,
        input   logic   [31:0]  rdata_prev,
        input   logic   [3:0]   rmask_prev,
        input   logic   [3:0]   set_prev,
        input   logic   [2:0]   plru_prev
    );
        $display("read hit\t from\taddr=0x%x, rmask=0b%d%d%d%d", addr, rmask[3], rmask[2], rmask[1], rmask[0]);
        setup_read_ufp_mem_itf(addr, rmask);
        @(posedge clk); // deassert after one cycle
        // assertion must be done here
        check_readout(rdata_prev, rmask_prev);
        if (set_prev !== 'x) check_plru(set_prev, plru_prev);
        stall_write_hit(stall);
        clear_ufp_mem_itf();
    endtask

    task write_hit (
        input   logic   [31:0]  addr,
        input   logic   [3:0]   wmask,
        input   logic   [31:0]  wdata,
        input   logic           stall,
        input   logic   [31:0]  rdata_prev,
        input   logic   [3:0]   rmask_prev,
        input   logic   [3:0]   set_prev,
        input   logic   [2:0]   plru_prev
    );
        $display("write hit\t to\taddr=0x%x, wmask=0b%d%d%d%d, wdata=0x%x", addr, wmask[3], wmask[2], wmask[1], wmask[0], wdata);
        setup_write_ufp_mem_itf(addr, wmask, wdata);
        @(posedge clk); // deassert after one cycle
        // assertion must be done here
        check_readout(rdata_prev, rmask_prev);
        if (set_prev !== 'x) check_plru(set_prev, plru_prev);
        stall_write_hit(stall);
        clear_ufp_mem_itf();
    endtask

    task read_clean_miss(
        input   logic   [31:0]  addr,
        input   logic   [3:0]   rmask,
        input   logic           stall,
        input   logic   [31:0]  rdata_prev,
        input   logic   [3:0]   rmask_prev,
        input   logic   [3:0]   set_prev,
        input   logic   [2:0]   plru_prev
    );
        $display("read clean miss\t from\taddr=0x%x, rmask=0b%d%d%d%d", addr, rmask[3], rmask[2], rmask[1], rmask[0]);
        setup_read_ufp_mem_itf(addr, rmask);
        @(posedge clk); // deassert after one cycle
        // assertion must be done here
        check_readout(rdata_prev, rmask_prev);
        if (set_prev !== 'x) check_plru(set_prev, plru_prev);
        stall_write_hit(stall);
        clobber_ufp_mem_itf();
        check_dfp_read();
        @(posedge clk);
        @(posedge clk);
        check_dfp_idle();
        clear_ufp_mem_itf();
    endtask
    
    task write_clean_miss (
        input   logic   [31:0]  addr,
        input   logic   [3:0]   wmask,
        input   logic   [31:0]  wdata,
        input   logic           stall,
        input   logic   [31:0]  rdata_prev,
        input   logic   [3:0]   rmask_prev,
        input   logic   [3:0]   set_prev,
        input   logic   [2:0]   plru_prev
    );
        $display("write clean miss to\taddr=0x%x, wmask=0b%d%d%d%d, wdata=0x%x", addr, wmask[3], wmask[2], wmask[1], wmask[0], wdata);
        setup_write_ufp_mem_itf(addr, wmask, wdata);
        @(posedge clk); // deassert after one cycle
        // assertion must be done here
        check_readout(rdata_prev, rmask_prev);
        if (set_prev !== 'x) check_plru(set_prev, plru_prev);
        stall_write_hit(stall);
        clobber_ufp_mem_itf();
        check_dfp_read();
        @(posedge clk);
        @(posedge clk);
        check_dfp_idle();
        clear_ufp_mem_itf();
    endtask

    task read_dirty_miss(
        input   logic   [31:0]  addr,
        input   logic   [3:0]   rmask,
        input   logic           stall,
        input   logic   [31:0]  rdata_prev,
        input   logic   [3:0]   rmask_prev,
        input   logic   [3:0]   set_prev,
        input   logic   [2:0]   plru_prev
    );
        $display("read dirty miss\t from\taddr=0x%x, rmask=0b%d%d%d%d", addr, rmask[3], rmask[2], rmask[1], rmask[0]);
        setup_read_ufp_mem_itf(addr, rmask);
        @(posedge clk); // deassert after one cycle
        // assertion must be done here
        check_readout(rdata_prev, rmask_prev);
        if (set_prev !== 'x) check_plru(set_prev, plru_prev);
        stall_write_hit(stall);
        clobber_ufp_mem_itf();
        check_dfp_write();
        @(posedge clk);
        check_dfp_read();
        @(posedge clk);
        @(posedge clk);
        check_dfp_idle();
        clear_ufp_mem_itf();
    endtask

    task write_dirty_miss(
        input   logic   [31:0]  addr,
        input   logic   [3:0]   wmask,
        input   logic   [31:0]  wdata,
        input   logic           stall,
        input   logic   [31:0]  rdata_prev,
        input   logic   [3:0]   rmask_prev,
        input   logic   [3:0]   set_prev,
        input   logic   [2:0]   plru_prev
    );
        $display("write dirty miss to\taddr=0x%x, wmask=0b%d%d%d%d, wdata=0x%x", addr, wmask[3], wmask[2], wmask[1], wmask[0], wdata);
        setup_write_ufp_mem_itf(addr, wmask, wdata);
        @(posedge clk); // deassert after one cycle
        // assertion must be done here
        check_readout(rdata_prev, rmask_prev);
        if (set_prev !== 'x) check_plru(set_prev, plru_prev);
        stall_write_hit(stall);
        clobber_ufp_mem_itf();
        check_dfp_write();
        @(posedge clk);
        check_dfp_read();
        @(posedge clk);
        @(posedge clk);
        check_dfp_idle();
        clear_ufp_mem_itf();
    endtask


    //---------------------------------------------------------------------------------
    // TODO: Main initial block that calls your tasks, then calls $finish
    //---------------------------------------------------------------------------------
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        clear_ufp_mem_itf();
        rst = 1'b1;
        repeat (5) @ (posedge clk);
        rst <= 1'b0;
        repeat (5) @ (posedge clk);

        // setup cache set 0
        read_clean_miss(32'd0, 4'b1010, 0, 'x, 4'b0000, 'x, 'x);
        read_hit(32'd0, 4'b1010, 0, 32'h01234567, 4'b1111, 0, 3'b101);
        read_hit(32'd0, 4'b1100, 0, 32'h01xx45xx, 4'b1010, 0, 3'b101);
        read_hit(32'd4, 4'b1010, 0, 32'h0123xxxx, 4'b1100, 0, 3'b101);
        @ (posedge clk);
        check_readout(32'h89xxcdxx, 4'b1010);
        check_plru(0, 3'b101);
        repeat (3) @ (posedge clk);

        read_hit(32'd8, 4'b1111, 0, 'x, 4'b0000, 'x, 'x);
        read_hit(32'd12, 4'b1111, 0, 32'hdeadbeef, 4'b1111, 0, 3'b101);
        read_hit(32'd0, 4'b0101, 0, 32'heceb3026, 4'b1111, 0, 3'b101);
        @ (posedge clk);
        check_readout(32'hxx23xx67, 4'b0101);
        check_plru(0, 3'b101);
        repeat (3) @ (posedge clk);

        read_hit(32'd16, 4'b1111, 0, 'x, 4'b0000, 'x, 'x);
        read_hit(32'd24, 4'b1111, 0, 32'hbeefdead, 4'b1111, 0, 3'b101);
        
        // setup cache set 1, way 3
        read_clean_miss(32'd32, 4'b1111, 0, 32'hcafebadf, 4'b1111, 'x, 'x);
        @ (posedge clk);
        check_readout(32'h76543210, 4'b1111);
        check_plru(1, 3'b101);
        @ (posedge clk);

        // multiple read hits
        read_hit(32'd24, 4'b1111, 0, 'x, 4'b0000, 'x, 'x);
        read_hit(32'd28, 4'b1111, 0, 32'hcafebadf, 4'b1111, 0, 3'b101);
        read_hit(32'd32, 4'b1111, 0, 32'h13572468, 4'b1111, 0, 3'b101);
        read_hit(32'd24, 4'b1111, 0, 32'h76543210, 4'b1111, 1, 3'b101);
        read_hit(32'd56, 4'b1111, 0, 32'hcafebadf, 4'b1111, 0, 3'b101);
        
        // stagger read hits
        read_hit(32'd24, 4'b1111, 0, 32'h89012345, 4'b1111, 1, 3'b101);
        @ (posedge clk);
        check_readout(32'hcafebadf, 4'b1111);
        check_plru(0, 3'b101);

        read_hit(32'd28, 4'b1111, 0, 'x, 4'b0000, 'x, 'x);
        @ (posedge clk);
        check_readout(32'h13572468, 4'b1111);
        check_plru(0, 3'b101);

        read_hit(32'd32, 4'b1111, 0, 'x, 4'b0000, 'x, 'x);
        @ (posedge clk);
        check_readout(32'h76543210, 4'b1111);
        check_plru(1, 3'b101);

        read_hit(32'd24, 4'b1111, 0, 'x, 4'b0000, 'x, 'x);
        @ (posedge clk);
        check_readout(32'hcafebadf, 4'b1111);
        check_plru(0, 3'b101);

        read_hit(32'd56, 4'b1111, 0, 'x, 4'b0000, 'x, 'x);
        @ (posedge clk);
        check_readout(32'h89012345, 4'b1111);
        check_plru(1, 3'b101);

        // lets try writing then reading to verify
        write_hit(32'd0, 4'b1111, 32'hffffffff, 0, 'x, 4'b0000, 'x, 'x);
        @ (posedge clk); // prevent stall
        read_hit (32'd0, 4'b1111,               0, 'x, 4'b0000, 'x, 'x);
        @ (posedge clk);
        check_readout(32'hffffffff, 4'b1111);
        check_plru(0, 3'b101);
        @ (posedge clk);

        // write hit with stall!
        write_hit(32'd0, 4'b1111, 32'hc3c3c3c3, 0, 'x, 4'b0000, 'x, 'x);
        read_hit (32'd0, 4'b1111,               1, 'x, 4'b0000, 0, 3'b101);
        @ (posedge clk);
        check_readout(32'hc3c3c3c3, 4'b1111);
        check_plru(0, 3'b101);
        @ (posedge clk);

        // consecutive write hit, with a write mask
        write_hit(32'd0, 4'b1111, 32'h24242424, 0,           'x, 4'b0000, 'x, 'x);
        write_hit(32'd0, 4'b1010, 32'h42424242, 1,           'x, 4'b0000, 0, 3'b101);
        write_hit(32'd4, 4'b1000, 32'hffffffff, 1,           'x, 4'b0000, 0, 3'b101);
        write_hit(32'd8, 4'b0001, 32'haaaaaaaa, 1,           'x, 4'b0000, 0, 3'b101);
        read_hit (32'd0, 4'b1111,               1,           'x, 4'b0000, 0, 3'b101);
        read_hit (32'd4, 4'b1111,               0, 32'h42244224, 4'b1111, 0, 3'b101);
        read_hit (32'd8, 4'b1111,               0, 32'hffabcdef, 4'b1111, 0, 3'b101);
        write_hit(32'd8, 4'b1111, 32'hbeefdead, 0, 32'hdeadbeaa, 4'b1111, 0, 3'b101);
        read_hit (32'd8, 4'b1111,               1,           'x, 4'b0000, 0, 3'b101);
        @ (posedge clk);
        check_readout(32'hbeefdead, 4'b1111);
        check_plru(0, 3'b101);
        repeat (3) @ (posedge clk);

        // write clean miss, populate set 2
        write_clean_miss(32'd80, 4'b1111, 32'h33443344, 0, 'x, 4'b0000, 'x, 'x);
        @ (posedge clk); // no stall
        read_hit(32'd64, 4'b1111, 0, 'x, 4'b0000, 'x, 'x);
        read_hit(32'd80, 4'b1111, 0, 32'h00002222, 4'b1111, 2, 3'b101);
        @ (posedge clk);
        check_readout(32'h33443344, 4'b1111);
        check_plru(2, 3'b101);
        repeat (3) @ (posedge clk);

        // write clean miss, populate set 3
        write_clean_miss(32'd120, 4'b1011, 32'h11223344, 0, 'x, 4'b0000, 'x, 'x);
        read_hit(32'd96, 4'b1111, 1, 'x, 4'b0000, 3, 3'b101);
        read_hit(32'd124, 4'b1111, 0, 32'hefefefef, 4'b1111, 3, 3'b101);
        read_hit(32'd120, 4'b1111, 0, 32'h12121212, 4'b1111, 3, 3'b101);
        @ (posedge clk);
        check_readout(32'h11343344, 4'b1111);
        check_plru(3, 3'b101);
        repeat (3) @ (posedge clk);

        // read clean miss with multiple read/write, but with different tag. populate set 1, way 1
        read_clean_miss(17*32+4, 4'b1111, 0, 'x, 4'b0000, 'x, 'x);
        read_hit(17*32+0, 4'b1111, 0, 32'h22222222, 4'b1111, 1, 3'b110);
        write_hit(17*32+0, 4'b0101, 32'h69696969, 0, 32'h33333333, 4'b1111, 1, 3'b110);
        read_hit(17*32+0, 4'b1111, 1, 'x, 4'b0000, 1, 3'b110);
        write_hit(17*32+8, 4'b1110, 32'h77667766, 0, 32'h33693369, 4'b1111, 1, 3'b110);
        read_hit(17*32+8, 4'b1111, 1, 'x, 4'b0000, 1, 3'b110);
        @ (posedge clk);
        check_readout(32'h77667711, 4'b1111);
        check_plru(1, 3'b110);
        repeat (3) @ (posedge clk);

        // populate set 1, all 4 ways
        read_clean_miss(33*32, 4'b1111, 0, 'x, 4'b0000, 'x, 'x); // fill way 2
        read_clean_miss(49*32, 4'b1111, 0, 32'h20342035, 4'b1111, 1, 3'b011); // fill way 0 
        read_hit(33*32+8, 4'b1111, 0, 32'h11111110, 4'b1111, 1, 3'b000); // read way 2, LRU is way 1 (dirty!) 
        read_hit(33*32+4, 4'b1111, 0, 32'h20302031, 4'b1111, 1, 3'b001);
        @ (posedge clk);
        check_readout(32'h20322033, 4'b1111);
        check_plru(1, 3'b001);
        repeat (3) @ (posedge clk);

        // set 1
        // way 0: addr=49*32, not dirty
        // way 1: addr=17*32,     dirty LRU
        // way 2: addr=33*32, not dirty MRU
        // way 3: addr= 1*32, not dirty

        // evict way 1, read dirty miss
        read_dirty_miss(65*32+8, 4'b1111, 0, 'x, 4'b0000, 'x, 'x);
        @ (posedge clk);
        check_readout(32'h42424242, 4'b1111);
        check_plru(1, 3'b010);
        repeat (3) @ (posedge clk);
        // way 1 is MRU and way 3 is LRU

        // evict way 3, not dirty
        read_clean_miss(17*32, 4'b1111, 0, 'x, 4'b0000, 'x, 'x);
        @ (posedge clk);
        check_readout(32'h33693369, 4'b1111);
        check_plru(1, 3'b111);
        repeat (3) @ (posedge clk);
        // way 3 is MRU and way 0 is LRU


        // write set 1, dirty all ways
        write_hit(49*32, 4'b1111, 32'h49494949, 0, 'x, 4'b0000, 'x, 'x);
        write_hit(65*32, 4'b1111, 32'h65656565, 1, 'x, 4'b0000, 1, 3'b100);
        write_hit(33*32, 4'b1111, 32'h33333333, 1, 'x, 4'b0000, 1, 3'b110);
        write_hit(17*32, 4'b1111, 32'h17171717, 1, 'x, 4'b0000, 1, 3'b011);
        // write dirty miss. evict way 0
        write_dirty_miss(1*32, 4'b1111, 32'h22222222, 1, 'x, 4'b0000, 1, 3'b111);
        // striped write hit-miss-hit
        write_hit(1*32, 4'b1111, 32'h01010101, 1, 'x, 4'b0000, 1, 3'b100);
        // verify read outs
        read_hit( 1*32, 4'b1111, 1, 'x, 4'b0000, 1, 3'b100);
        read_hit(65*32, 4'b1111, 0, 32'h01010101, 4'b1111, 1, 3'b100);
        read_hit(33*32, 4'b1111, 0, 32'h65656565, 4'b1111, 1, 3'b110);
        read_hit(17*32, 4'b1111, 0, 32'h33333333, 4'b1111, 1, 3'b011);
        @ (posedge clk);
        check_readout(32'h17171717, 4'b1111);
        check_plru(1, 3'b111);
        repeat (3) @ (posedge clk);

        // set 1
        // way 0: addr= 1*32, dirty LRU
        // way 1: addr=65*32, dirty 
        // way 2: addr=33*32, dirty 
        // way 3: addr=17*32, dirty MRU

        // consecutive read dirty misses (evict a way and then read from the evicted address)
        // evict way 0
        read_dirty_miss(49*32, 4'b1111, 0, 'x, 4'b0000, 'x, 'x);
        // evict way 2
        read_dirty_miss( 1*32, 4'b1111, 0, 32'h49494949, 4'b1111, 1, 3'b100);
        // evict way 1
        read_dirty_miss(33*32, 4'b1111, 0, 32'h01010101, 4'b1111, 1, 3'b001);
        // evict way 3 
        read_dirty_miss(65*32, 4'b1111, 0, 32'h33333333, 4'b1111, 1, 3'b010);
        @ (posedge clk);
        check_readout(32'h65656565, 4'b1111);
        check_plru(1, 3'b111);
        repeat (3) @ (posedge clk);

        // set 1
        // way 0: addr=49*32, LRU
        // way 1: addr=33*32
        // way 2: addr= 1*32
        // way 3: addr=65*32, MRU

        // write clean misses set 1, dirty all ways
        // evict way 0
        write_clean_miss(17*32, 4'b1111, 32'h17000000, 0, 'x, 4'b0000, 'x, 'x);
        // evict way 2
        write_clean_miss(49*32, 4'b1111, 32'h49000000, 1, 'x, 4'b0000, 1, 3'b100);
        // evict way 1
        write_clean_miss( 1*32, 4'b1111, 32'h01000000, 1, 'x, 4'b0000, 1, 3'b001);
        // evict way 3
        write_clean_miss(33*32, 4'b1111, 32'h33000000, 1, 'x, 4'b0000, 1, 3'b010);
        // verify read outs
        read_hit(17*32, 4'b1111, 1, 'x, 4'b0000, 1, 3'b111);
        read_hit( 1*32, 4'b1111, 0, 32'h17000000, 4'b1111, 1, 3'b100);
        read_hit(49*32, 4'b1111, 0, 32'h01000000, 4'b1111, 1, 3'b110);
        read_hit(33*32, 4'b1111, 0, 32'h49000000, 4'b1111, 1, 3'b011);
        @ (posedge clk);
        check_readout(32'h33000000, 4'b1111);
        check_plru(1, 3'b111);
        repeat (3) @ (posedge clk);

        // set 1
        // way 0: addr=17*32, LRU
        // way 1: addr= 1*32
        // way 2: addr=49*32
        // way 3: addr=33*32, MRU

        // consecutive write dirty misses
        // evict way 0
        write_dirty_miss(65*32, 4'b1111, 32'h65000000, 0, 'x, 4'b0000, 'x, 'x);
        // evict way 2
        write_dirty_miss(17*32, 4'b1111, 32'h17000000, 1, 'x, 4'b0000, 1, 3'b100);
        // evict way 1
        write_dirty_miss(49*32, 4'b1111, 32'h49000000, 1, 'x, 4'b0000, 1, 3'b001);
        // evict way 3
        write_dirty_miss( 1*32, 4'b1111, 32'h01000000, 1, 'x, 4'b0000, 1, 3'b010);
        // verify read outs
        read_hit(65*32, 4'b1111, 1, 'x, 4'b0000, 1, 3'b111);
        read_hit(49*32, 4'b1111, 0, 32'h65000000, 4'b1111, 1, 3'b100);
        read_hit(17*32, 4'b1111, 0, 32'h49000000, 4'b1111, 1, 3'b110);
        read_hit( 1*32, 4'b1111, 0, 32'h17000000, 4'b1111, 1, 3'b011);
        @ (posedge clk);
        check_readout(32'h01000000, 4'b1111);
        check_plru(1, 3'b111);
        repeat (3) @ (posedge clk);

        // set 1
        // way 0: addr=65*32, LRU
        // way 1: addr=49*32
        // way 2: addr=17*32
        // way 3: addr= 1*32, MRU

        // capacity miss: fill all 64 cache lines, then evict
        // for (int i = 0; i < 16; i++) begin
        //     // fill ways
        //     write_clean_miss(32*(i+0*16), 4'b1111, (i+0*16), 0, 'x, 4'b0000, 'x, 'x); // way 3
        //     write_clean_miss(32*(i+5*16), 4'b1111, (i+5*16), 1, 'x, 4'b0000, i, 3'b101); // way 1
        //     @ (posedge clk);
        //     check_plru(i, 3'b110);
        //     write_clean_miss(32*(i+7*16), 4'b1111, (i+7*16), 0, 'x, 4'b0000, 'x, 'x); // way 2
        //     write_clean_miss(32*(i+9*16), 4'b1111, (i+9*16), 1, 'x, 4'b0000, i, 3'b011); // way 0
        //     // evict way 3
        //     write_dirty_miss(32*(i+6*16), 4'b1111, (i+6*16), 1, 'x, 4'b0000, i, 3'b000); // way 3
        //     @ (posedge clk);
        //     check_plru(i, 3'b101);
        // end
        // for (int i = 0; i < 16; i++) begin
        //     // read out
        //     read_hit(32*(i+6*16), 4'b1111, 0, 'x, 4'b0000, 'x, 'x); // way 3
        //     read_hit(32*(i+7*16), 4'b1111, 0, (i+6*16), 4'b1111, i, 3'b101); // way 2
        //     read_hit(32*(i+9*16), 4'b1111, 0, (i+7*16), 4'b1111, i, 3'b001); // way 0
        //     @ (posedge clk);
        //     check_readout((i+9*16), 4'b1111);
        //     check_plru(i, 3'b000);
        //     read_hit(32*(i+5*16), 4'b1111, 0, 'x, 4'b0000, 'x, 'x); // way 1
        //     @ (posedge clk);
        //     check_readout((i+5*16), 4'b1111);
        //     check_plru(i, 3'b010);
        // end

        // buffer before finish
        repeat (10) @ (posedge clk);
        $finish;
    end

    always @(posedge clk) begin
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $fatal;
        end
        if (dfp_mem_itf.error | ufp_mem_itf.error != 0) begin
            repeat (2) @(posedge clk);
            $fatal;
        end
        timeout <= timeout - 1;
    end


endmodule : top_tb
