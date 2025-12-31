class nqueueRandGen #(
    parameter               WIDTH = 32,
    parameter               NSIZE_BITS = 0,
    parameter               NSIZE = 2 ** NSIZE_BITS
);
    rand bit    [WIDTH-1:0] din[NSIZE];
    rand bit    [NSIZE-1:0] enqueue;
    rand bit    [NSIZE-1:0] dequeue;
    constraint queue_const {
        $countones({1'b0, enqueue} + 1) == 1;
        $countones({1'b0, dequeue} + 1) == 1;
    }
endclass

module n_queue_tb;
    timeunit 1ns;

    localparam WIDTH = 32;
    localparam DEPTH_BITS = 3;
    localparam NSIZE_BITS = 0;
    localparam NSIZE = 2 ** NSIZE_BITS;
    localparam DEPTH = 2 ** DEPTH_BITS;

    bit clk, rst;
    logic [WIDTH-1:0] din[NSIZE];
    logic [WIDTH-1:0] dout[NSIZE];
    logic [NSIZE-1:0] enqueue;
    logic [NSIZE-1:0] dequeue;
    logic [DEPTH_BITS:0] freespace;
    logic [DEPTH_BITS:0] elemcount;
    logic [WIDTH-1:0] dout_store[NSIZE];

    bit verbose;

    n_queue #(.WIDTH(WIDTH), .DEPTH_BITS(DEPTH_BITS), .NSIZE_BITS(NSIZE_BITS)) dut (.*);
    nqueueRandGen #(.WIDTH(WIDTH), .NSIZE_BITS(NSIZE_BITS)) gen;

    int i;

    always #1 clk = ~clk;

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst <= 1'b1;
        enqueue <= '0;
        dequeue <= '0;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
    end

    task enqueue_all_op();
        enqueue <= '1;
        dequeue <= '0;
        din <= gen.din;
        @(posedge clk);
        #0.001;
        if (verbose) begin
            for(i = 0; i < NSIZE; i++) begin
                $display("ENQ [%h]: [%h]", i, din[i]);
            end
        end
        enqueue <= '0;
    endtask

    task dequeue_all_op();
        dequeue <= '1;
        enqueue <= '0;
        for(i = 0; i < NSIZE; i++) begin
            dout_store[i] <= dout[i];
        end
        @(posedge clk);
        #0.001;
        if (verbose) begin
            for(i = 0; i < NSIZE; i++) begin
                $display("DEQ [%h]: [%h]", i, dout_store[i]);
            end
        end
        dequeue <= '0;
    endtask

    task dequeue_t();
        gen.randomize();
        enqueue_all_op();
        dequeue_all_op();
        if (dout_store !== din) begin
            $error("Data mismatch. Write: [%h], Read: [%h]", din[0], dout_store[0]);
            $fatal;
        end
    endtask

    task crossed_t();
        for (int i = 0; i < 100; i++) begin
            dequeue_t();
        end
    endtask

    task random_t();
        enqueue <= '0;
        dequeue <= '0;
        for(int i = 0; i < 100; i++) begin
            @(posedge clk);
            #0.001;
            gen.randomize();
            if(freespace < (DEPTH_BITS+1)'($countones(gen.enqueue))) begin
                enqueue <= NSIZE'((2 ** freespace) - 1);
            end else begin
                enqueue <= gen.enqueue;
            end
            if(elemcount < (DEPTH_BITS+1)'($countones(gen.dequeue))) begin
                dequeue <= NSIZE'((2 ** elemcount) - 1);
            end else begin
                dequeue <= gen.dequeue;
            end
            din <= gen.din;
        end
    endtask

    initial begin
        gen = new;
        @(posedge clk iff ~rst);

        verbose <= '1;
        enqueue <= '0;
        dequeue <= '0;

        crossed_t();

        @(posedge clk);
        $display("SIMULATION SUCCESS");
        $finish;
    end
endmodule
