module alu_tb;
    timeunit 1ps;
    timeprecision 1ps;
    bit clk;
    always #1 clk = ~clk;
    bit rst;
    logic   [31:0]  a,b;
    logic           start;
    logic           signage;

    multiplier #(
        .DELAY(3)
    ) dut(
        .clk    (clk),
        .rst    (rst),
        .signage(signage),
        .start  (start),
        .a      (a),
        .b      (b),   
        .product(),
        .resp   ()
    );
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst = 1'b1;
        a       <= 'x;
        b       <= 'x;
        start   <= '0;
        signage <= '0;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
        repeat (10) @(posedge clk);
        // perform unsigned multiplication
        a       <= 32'd12;
        b       <= 32'd4;
        start   <= '1;
        signage <= '0;
        @ (posedge clk);
        start   <= '0;
        signage <= 'x;
        @ (posedge clk);
        // dut.unsigned_mult_seq.hold <= '1;
        @ (posedge clk);
        // dut.unsigned_mult_seq.hold <= '0;
        @ (posedge dut.resp);
        // repeat(2) @ (posedge clk);
        // perform signed multiplication
        a       <= -32'd12;
        b       <= -32'd4;
        start   <= '1;
        signage <= '1;
        @ (posedge clk);
        start   <= '0;
        signage <= 'x;
        repeat(20) @ (posedge clk);
        $finish;
    end
endmodule