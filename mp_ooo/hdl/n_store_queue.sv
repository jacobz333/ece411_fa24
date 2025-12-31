module n_store_queue
import rv32i_types::*;
#(
    parameter                   DEPTH_BITS = 8,
    localparam                  DEPTH_N = 2 ** DEPTH_BITS,
    localparam  [DEPTH_BITS:0]  DEPTH   = 2 ** DEPTH_BITS,
    parameter                   NSIZE = 1,
    localparam                  NSIZE_BITS = $clog2(NSIZE),
    parameter                   WIDTH = 32
)(
    input   logic                           clk,
    input   logic                           rst,
    input   sb_entry_t                      din[NSIZE],
    input   logic   [NSIZE-1:0]             enqueue,
    input   logic   [NSIZE-1:0]             dequeue,
    output  sb_entry_t                      dout[NSIZE],
    output  logic   [DEPTH_BITS:0]          freespace,
    output  logic   [DEPTH_BITS:0]          elemcount,
    output  sb_entry_t                      Qmem[DEPTH],
    output  logic unsigned [DEPTH_BITS-1:0] head_addr
);

    logic               [NSIZE_BITS:0]     num_of_dequeue_bits;
    logic               [NSIZE_BITS:0]     num_of_enqueue_bits;

    logic   unsigned    [DEPTH_BITS-1:0]   tail_addr;

    sb_entry_t                             Qmem_m[NSIZE];
    logic               [NSIZE:0]          Qmem_write_m[DEPTH];

    logic   could_be_empty;
 
    int unsigned count_idx;
    int unsigned j;

    always_ff @(posedge clk) begin
        if(rst) begin
            tail_addr <= '0;
            head_addr <= '0;
            could_be_empty <= 1'b1;
        end else begin
            head_addr <= (DEPTH_BITS)'(32'(num_of_enqueue_bits) + 32'(head_addr));

            if(num_of_dequeue_bits > num_of_enqueue_bits && 32'(num_of_dequeue_bits - num_of_enqueue_bits) > 32'(elemcount)) begin
                tail_addr <= (DEPTH_BITS)'(32'(num_of_enqueue_bits) + 32'(head_addr));
            end else begin
                tail_addr <= (DEPTH_BITS)'(32'(num_of_dequeue_bits) + 32'(tail_addr));
            end

            if(num_of_enqueue_bits < num_of_dequeue_bits) begin
                could_be_empty <= 1'b1;
            end else if(num_of_enqueue_bits > num_of_dequeue_bits) begin
                could_be_empty <= 1'b0;
            end
        end
    end

    generate for(genvar i = 0; i < DEPTH_N; i++) begin
        always_ff @(posedge clk) begin
            if(rst) begin
                Qmem[i] <= '0; // Must be 0 so that write mask starts at 0
            end else if(Qmem_write_m[i] != '0) begin
                //ifdef NQUEUE_N_ONE
                    Qmem[i] <= Qmem_m[0];
                //else
                //    Qmem[i] <= Qmem_m[(NSIZE_BITS)'(32'(Qmem_write_m[i]) - (32)'(1))];
                //endif
            end
        end
    end endgenerate
 
    always_comb begin
        num_of_dequeue_bits = '0;
        num_of_enqueue_bits = '0;

        for(count_idx = 0; count_idx < NSIZE; count_idx++) begin
            num_of_enqueue_bits += (NSIZE_BITS+1)'(enqueue[count_idx]);
            num_of_dequeue_bits += (NSIZE_BITS+1)'(dequeue[count_idx]);
        end

        if(tail_addr < head_addr) begin
            elemcount = (DEPTH_BITS+1)'(head_addr - tail_addr);
        end else if(tail_addr > head_addr) begin
            elemcount = DEPTH - (tail_addr - head_addr);
        end else begin
            elemcount = could_be_empty ? '0 : DEPTH;
        end
        freespace = DEPTH - elemcount;

        Qmem_write_m = '{default: '0};

        for(j = 0; j < NSIZE; j++) begin
            Qmem_m[j] = 'x;
            if((DEPTH_BITS + 1)'(j) < elemcount)
                dout[j] = Qmem[tail_addr + DEPTH_BITS'(j)];
            else
                dout[j] = 'x;
            if(enqueue[j]) begin
                Qmem_m[j] = din[j];
                Qmem_write_m[head_addr + DEPTH_BITS'(j)] = (NSIZE+1)'(j + 1);
            end
        end
    end
endmodule
