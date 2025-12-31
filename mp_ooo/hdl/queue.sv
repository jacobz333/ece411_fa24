module queue #(
            parameter                   DEPTH_INDEX = 8,
            parameter                   WIDTH       = 32
)(
    input   logic                       clk,
    input   logic                       rst,
    input   logic   [WIDTH-1:0]         din,
    input   logic                       enqueue,
    input   logic                       dequeue,
    output  logic   [WIDTH-1:0]         dout,
    output  logic                       Qempty, 
    output  logic                       Qfull, 
    output  logic                       Qresp
);
            /* For avoid Lint Warnings */
            localparam          [DEPTH_INDEX-1:0]   CONST_ONE_A = '0 + 1;
            localparam          [DEPTH_INDEX:0]     CONST_ONE_D = '0 + 1;
            localparam          [DEPTH_INDEX:0]     DEPTH       = 2 ** DEPTH_INDEX;

            logic               [WIDTH-1:0]         Qmem        [DEPTH];

            logic   unsigned    [DEPTH_INDEX-1:0]   head_addr;
            logic   unsigned    [DEPTH_INDEX-1:0]   tail_addr;

    always_ff @(posedge clk) begin
        if (rst) begin
            tail_addr <= '0;
            head_addr <= '0;
            Qresp <= '0;
            Qfull <= '0;
            Qempty <= '1;
        end else begin
            /* enqueue */
            if (enqueue && ~dequeue && ~Qfull) begin
                head_addr <= head_addr + CONST_ONE_A;
                Qmem[head_addr] <= din;
                Qresp <= '1;
                if (head_addr + CONST_ONE_A == tail_addr) begin
                    Qfull <= '1;
                end else begin
                    Qfull <= '0;
                    Qempty <= '0;
                end
            end
            /* dequeue */
            if (dequeue && ~enqueue && ~Qempty) begin
                tail_addr <= tail_addr + CONST_ONE_A;
                dout <= Qmem[tail_addr];
                Qresp <= '1;
                if (head_addr == tail_addr + CONST_ONE_A) begin
                    Qempty <= '1;
                end else begin
                    Qfull <= '0;
                    Qempty <= '0;
                end
            end
            /* simutanous enq deq */ 
            if (enqueue && dequeue) begin
                if (Qempty) begin
                    dout <= din;
                end else begin
                    head_addr <= head_addr + CONST_ONE_A;
                    tail_addr <= tail_addr + CONST_ONE_A;
                    Qmem[head_addr] <= din;
                    dout <= Qmem[tail_addr];
                end
                Qresp <= '1;
            end
        end
    end

endmodule
