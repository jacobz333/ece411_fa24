class randGen #(
    parameter               WIDTH = 32
);
    rand bit    [WIDTH-1:0] din;
    rand bit                enqueue;
    rand bit                dequeue;
endclass

module queue_tb;
    timeunit 1ps;
    timeprecision 1ps;

    localparam WIDTH = 8;
    localparam DEPTH_INDEX = 4;
    localparam DEPTH = 2 ** DEPTH_INDEX;

    bit clk, rst;
    logic [WIDTH-1:0] din, dout;
    bit enqueue, dequeue;
    logic Qempty, Qfull, Qresp;

    bit verbose;
    
    logic [WIDTH-1:0] refmem [DEPTH+1];
    int head, tail, count;
    logic [WIDTH-1:0] refout;

    queue #(.WIDTH(WIDTH), .DEPTH_INDEX(DEPTH_INDEX)) dut (.*);
    // simple_queue #(.WIDTH(WIDTH), .DEPTH_INDEX(DEPTH_INDEX)) dut (.*);

    randGen #(.WIDTH(WIDTH)) gen;

    always #1 clk = ~clk;

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst = 1'b0;
    end

    task enqueue_op();
        enqueue = '1;
        din = gen.din;
        @(posedge clk);
        if (verbose)
            $display("ENQ [%h]", din);
        enqueue = '0;
    endtask

    task dequeue_op();
        dequeue = '1;
        @(posedge clk);
        if (verbose)
            $display("DEQ [%h]", dout);
        dequeue = '0;
    endtask

    task enqueue_t();
        gen.randomize();
        enqueue_op();
    endtask

    task dequeue_t();
        gen.randomize();
        enqueue_op();
        dequeue_op();
        if (dout !== din) begin
            $error("Data mismatch. Write: [%h], Read: [%h]", din, dout);
            $fatal;
        end
    endtask

    task crossed_t();
        for (int i = 0; i < 100; i++) begin
            dequeue_t();
        end

        gen.randomize();
        enqueue_op();
        dequeue_op();
        
        gen.randomize();
        enqueue_op();
        
        gen.randomize();
        enqueue_op();

        gen.randomize();
        enqueue_op();

        dequeue_op();
        dequeue_op();
        dequeue_op();
    endtask

    task full_empty_t();
        if (Qempty !== 1) begin
            $display("Qempty error. ");
            $fatal;
        end

        for (int i = 0; i < DEPTH; i++) begin
            gen.randomize();
            enqueue_op();
            refmem[i] = din;
        end

        if (Qfull !== 1) begin
            $display("Qfull error. ");
            $fatal;
        end

        gen.randomize();
        enqueue_op();

        if (Qfull !== 1) begin
            $display("Qfull error. ");
            $fatal;
        end

        for (int i = 0; i < DEPTH; i++) begin
            dequeue_op();
            if (dout !== refmem[i]) begin
                $error("Data mismatch. Write: [%h], Read: [%h]", refmem[i], dout);
                $fatal;
            end
        end

        if (Qempty !== 1) begin
            $display("Qempty error. ");
            $fatal;
        end

        dequeue_op();

        if (Qempty !== 1) begin
            $display("Qempty error. ");
            $fatal;
        end
    endtask

    task concurrent_t();
        logic [WIDTH-1:0] refout;

        gen.randomize();
        enqueue = '1;
        dequeue = '1;
        din = gen.din;
        @(posedge clk);
        if (~Qempty) begin
            $display("Qempty error. ");
            $fatal;
        end
        if (dout !== din) begin
            $error("Data mismatch. Write: [%h], Read: [%h]", din, dout);
            $fatal;
        end
        
        gen.randomize();
        dequeue = '0;
        enqueue_op();
        if (Qempty) begin
            $display("Qempty error. ");
        enqueue = '0;
        dequeue = '0;
        @(posedge clk);
            $fatal;
        end

        refout = din;
        gen.randomize();
        enqueue = '1;
        dequeue = '1;
        din = gen.din;
        @(posedge clk);
        if (Qempty) begin
            $display("Qempty error. ");
            $fatal;
        end
        if (dout !== refout) begin
            $error("Data mismatch. Write: [%h], Read: [%h]", refout, dout);
            $fatal;
        end

        dequeue = '0;
        for (int i = 0; i < DEPTH - 1; i++) begin
            enqueue_op();
        end
        if (~Qfull) begin
            $display("Qfull error. ");
            $fatal;
        end
        
        refout = din;
        gen.randomize();
        enqueue = '1;
        dequeue = '1;
        din = gen.din;
        @(posedge clk);
        if (~Qfull) begin
            $display("Qfull error. ");
            $fatal;
        end
        if (dout !== refout) begin
            $error("Data mismatch. Write: [%h], Read: [%h]", refout, dout);
            $fatal;
        end

    endtask

    task random_t();
        head = 0;
        tail = 0;
        count = 0;
        refout = '0;
        for (int i = 0; i < 12345; i++) begin
            gen.randomize();
            enqueue = gen.enqueue;
            dequeue = gen.dequeue;
            din = gen.din;
            if (verbose) begin
                if (enqueue) begin
                    $display("Try ENQ [%h]", din);
                end
                if (dequeue) begin
                    $display("Try DEQ [%h]", dout);
                end
            end
            if (enqueue && (count != DEPTH || (dequeue && count == DEPTH))) begin
                refmem[head] = din;
                head++;
                count++;
                if (head == DEPTH+1) head = 0;
            end
            if (dequeue && count != 0) begin
                refout = refmem[tail];
                tail++;
                count--;
                if (tail == DEPTH+1) tail = 0;
            end
            @(posedge clk);
            if (dequeue && count != 0 && dout !== refout) begin
                $error("Data mismatch. Expected: [%h], Read: [%h]", refout, dout);
                enqueue = '0;
                dequeue = '0;
                @(posedge clk);
                $fatal;
            end
        end
    endtask

    task random_simple_t();
        head = 0;
        tail = 0;
        count = 0;
        refout = '0;
        for (int i = 0; i < 12345; i++) begin
            gen.randomize();
            enqueue = gen.enqueue;
            dequeue = ~gen.enqueue;
            din = gen.din;
            if (verbose) begin
                if (enqueue) begin
                    $display("Try ENQ [%h]", din);
                end
                if (dequeue) begin
                    $display("Try DEQ [%h]", dout);
                end
            end
            if (enqueue && (count != DEPTH || (dequeue && count == DEPTH))) begin
                refmem[head] = din;
                head++;
                count++;
                if (head == DEPTH+1) head = 0;
            end
            if (dequeue && count != 0) begin
                refout = refmem[tail];
                tail++;
                count--;
                if (tail == DEPTH+1) tail = 0;
            end
            @(posedge clk);
            if (dequeue && count != 0 && dout !== refout) begin
                $error("Data mismatch. Expected: [%h], Read: [%h]", refout, dout);
                enqueue = '0;
                dequeue = '0;
                @(posedge clk);
                $fatal;
            end
        end
    endtask

    initial begin
        gen = new;
        @(posedge clk iff ~rst);

        if (~Qempty) begin
            $error("Start Qempty Error");
            $fatal;
        end
        @(posedge clk);
        if (~Qempty) begin
            $error("Start Qempty Error");
            $fatal;
        end

        verbose = '0;

        // enqueue_t();
        // dequeue_t();
        // crossed_t();
        // full_empty_t();
        // concurrent_t();
        // random_simple_t();
        random_t();

        @(posedge clk);
        $display("SIMULATION SUCCESS");
        $finish;
    end
endmodule
