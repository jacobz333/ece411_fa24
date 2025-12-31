module store_queue
import rv32i_types::*;
#(
            parameter                   DEPTH_INDEX = 8,
            /* For avoid Lint Warnings */
            localparam          [DEPTH_INDEX-1:0]   CONST_ONE_A = '0 + 1,
            localparam          [DEPTH_INDEX:0]     CONST_ONE_D = '0 + 1,
            localparam          DEPTH       = 2 ** DEPTH_INDEX

)(
    input   logic                       clk,
    input   logic                       rst,
    input   sb_entry_t                  din,
    input   logic                       enqueue,
    input   logic                       dequeue,
    output  sb_entry_t                  dout,
    output  logic                       Qempty,
    output  logic                       Qfull,
    output  logic                       enq_resp,
    output  logic                       deq_resp,
    output  sb_entry_t                  Qmem[DEPTH],

    // input   logic                       load,
    // input   logic   [DEPTH_INDEX-1:0]   load_idx,
    // input   sb_entry_t                  load_din,

    output  logic   [DEPTH_INDEX-1:0]   Qtail_addr
);
            
            logic   unsigned    [DEPTH_INDEX-1:0]   head_addr;
            logic   unsigned    [DEPTH_INDEX-1:0]   tail_addr;

    assign Qtail_addr = tail_addr;

    always_ff @(posedge clk) begin
        if (rst) begin
            tail_addr <= '0;
            head_addr <= '0;
            enq_resp  <= '0;
            deq_resp  <= '0;
            Qfull     <= '0;
            Qempty    <= '1;
            for (int i = 0; i < DEPTH; i++) begin
                Qmem[i] <= '0;
            end
        end else begin
            /* enqueue */
            if (enqueue && ~dequeue && ~Qfull) begin
                head_addr <= head_addr + CONST_ONE_A;
                Qmem[head_addr] <= din;
                enq_resp <= '1;
                if (head_addr + CONST_ONE_A == tail_addr) begin
                    Qfull <= '1;
                end else begin
                    Qfull <= '0;
                    Qempty <= '0;
                end
            end
            /* dequeue */
            else if (dequeue && ~enqueue && ~Qempty) begin
                tail_addr <= tail_addr + CONST_ONE_A;
                // dout <= Qmem[tail_addr];
                deq_resp <= '1;
                if (head_addr == tail_addr + CONST_ONE_A) begin
                    Qempty <= '1;
                end else begin
                    Qfull <= '0;
                    Qempty <= '0;
                end
            end
            /* simutanous enq deq */ 
            else if (enqueue && dequeue) begin
                if (Qempty) begin
                    Qmem[head_addr] <= din;
                    head_addr <= head_addr + CONST_ONE_A;
                    enq_resp <= '1;
                end else begin
                    head_addr <= head_addr + CONST_ONE_A;
                    tail_addr <= tail_addr + CONST_ONE_A;
                    Qmem[head_addr] <= din;
                    // dout <= Qmem[tail_addr];
                    enq_resp <= '1;
                    deq_resp <= '1;
                end
            end else begin
                // dout.valid <= '0;
                enq_resp <= '0;
                deq_resp <= '0;
            end
        end
    end

    always_comb begin
        dout = Qmem[tail_addr];
    end

endmodule
