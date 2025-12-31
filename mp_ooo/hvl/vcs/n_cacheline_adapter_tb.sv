class nCachelineAdapterRandGen;
    rand bit    [255:0] wdata; 
    rand bit    [31:0]  addr;
    constraint addr_const {
        addr[7:0] == '0;
    }
endclass

//module n_cacheline_adapter(
//    input   logic           clk,
//    input   logic           rst,
//
//    // bmem interface
//    output  logic   [31:0]  bmem_addr,
//    output  logic           bmem_read,
//    output  logic           bmem_write,
//    output  logic   [63:0]  bmem_wdata,
//    input   logic           bmem_ready,
//
//    input   logic   [31:0]  bmem_raddr,
//    input   logic   [63:0]  bmem_rdata,
//    input   logic           bmem_rvalid,
//
//    // cache interface
//    input   logic   [31:0]  cache_addr,
//    input   logic           cache_read,
//    input   logic           cache_write,
//    output  logic   [255:0] cache_rdata,
//    input   logic   [255:0] cache_wdata,
//    output  logic           cache_resp
//);

module n_cacheline_adapter_tb;
    timeunit 1ns;

    logic           clk;
    logic           rst;
    logic   [255:0] rdata;

    mem_itf_banked bmem_itf(.*);
    mem_itf_wo_mask #(1, 256) cache_mem_itf(.*);
    dram_w_burst_frfcfs_controller banked_memory(.itf(bmem_itf));

    nCachelineAdapterRandGen gen;

    n_cacheline_adapter dut(
        .clk            (clk),
        .rst            (rst),

        .bmem_addr  (bmem_itf.addr  ),
        .bmem_read  (bmem_itf.read  ),
        .bmem_write (bmem_itf.write ),
        .bmem_wdata (bmem_itf.wdata ),
        .bmem_ready (bmem_itf.ready ),
        .bmem_raddr (bmem_itf.raddr ),
        .bmem_rdata (bmem_itf.rdata ),
        .bmem_rvalid(bmem_itf.rvalid),
        .cache_addr (cache_mem_itf.addr [0]),
        .cache_read (cache_mem_itf.read [0]),
        .cache_write(cache_mem_itf.write[0]),
        .cache_rdata(cache_mem_itf.rdata[0]),
        .cache_wdata(cache_mem_itf.wdata[0]),
        .cache_resp (cache_mem_itf.resp [0])
    );

    always #1 clk = ~clk;

    integer i;

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst <= 1'b1;
        clk <= 1'b0;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
    end

    task random_t();
        for(i = 0; i < 10; i++) begin
            gen.randomize();
            cache_mem_itf.addr[0] <= gen.addr;
            cache_mem_itf.wdata[0] <= gen.wdata;
            cache_mem_itf.write[0] <= 1'b1;
            cache_mem_itf.read[0] <= 1'b0;
            #2.001;
            wait(cache_mem_itf.resp[0]);
            cache_mem_itf.write[0] <= 1'b0;
            cache_mem_itf.read[0] <= 1'b1;
            #2.001;
            wait(cache_mem_itf.resp[0]);
            rdata <= cache_mem_itf.rdata[0];
        end
    endtask

    initial begin
        gen = new;
        cache_mem_itf.read[0] <= 1'b0;
        cache_mem_itf.write[0] <= 1'b0;
        @(posedge clk iff ~rst);

        random_t();

        @(posedge clk);
        $display("SIMULATION SUCCESS");
        $finish;
    end
endmodule
