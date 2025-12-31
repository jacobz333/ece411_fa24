module rob
import rv32i_types::*;
#(
    parameter                   DEPTH_BITS = 3,
    parameter                   DEPTH_N = 2 ** DEPTH_BITS,
    parameter                   NSIZE = 1,
    localparam                  NSIZE_BITS = $clog2(NSIZE),
    parameter                   PR_BITS    = 6,
    parameter                   CDB_COUNT  = 1
)(
    input   logic                       clk,
    input   logic                       rst,
    input   rob_entry_t                 din[NSIZE],
    input   logic   [NSIZE-1:0]         enqueue,
    input   logic   [NSIZE-1:0]         dequeue,
    input   cdb_t                       cdb[CDB_COUNT],
    output  rob_entry_t                 dout[NSIZE],
    output  logic   [DEPTH_BITS-1:0]    rob_id_to_insert[NSIZE],
    output  logic   [DEPTH_BITS:0]      freespace,
    output  logic   [DEPTH_BITS:0]      elemcount,
    
    output  logic unsigned [DEPTH_BITS-1:0]    current_tail_addr,

    input   logic                       flush
);

    localparam          [DEPTH_BITS:0]     DEPTH       = 2 ** DEPTH_BITS;

    rob_entry_t                            Qmem[DEPTH];

    logic               [NSIZE_BITS:0]     num_of_dequeue_bits;
    logic               [NSIZE_BITS:0]     num_of_enqueue_bits;

    logic   unsigned    [DEPTH_BITS-1:0]   head_addr;
    logic   unsigned    [DEPTH_BITS-1:0]   tail_addr;

    rob_entry_t                            Qmem_m[NSIZE];
    logic               [NSIZE:0]          Qmem_write_m[DEPTH];

    cdb_t                                  cdb_mapping[DEPTH];

    logic   could_be_empty;
 
    int unsigned count_idx;
    int unsigned j;
    int unsigned l;

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

            // on wrong branch commit, flush all following ROB
            if (flush) begin
                // tail_addr <= head_addr;
                // could_be_empty <= '1;
            end
        end
    end

    generate for(genvar i = 0; i < DEPTH_N; i++) begin : rob_block_b
        always_ff @(posedge clk) begin
            if(rst) begin
                Qmem[i] <= 'x;
            end else if(Qmem_write_m[i] != '0) begin
                //ifdef ROB_N_ONE
                //    Qmem[i] <= Qmem_m[0];
                //else
                    Qmem[i] <= Qmem_m[(NSIZE_BITS)'(32'(Qmem_write_m[i]) - (32)'(1))];
                //endif
            end else if(cdb_mapping[i].ready) begin
                Qmem[i].ready <= 1'b1;
                Qmem[i].monitor_rd_wdata <= cdb_mapping[i].result;
                Qmem[i].monitor_rs1_rdata <= cdb_mapping[i].monitor_rs1_rdata;
                Qmem[i].monitor_rs2_rdata <= cdb_mapping[i].monitor_rs2_rdata;
                Qmem[i].monitor_mem_rmask <= cdb_mapping[i].monitor_mem_rmask;
                Qmem[i].monitor_mem_rdata <= cdb_mapping[i].monitor_mem_rdata;
                Qmem[i].monitor_mem_addr <= cdb_mapping[i].monitor_mem_addr;
            end
        end
    end endgenerate
 
    always_comb begin
        current_tail_addr = tail_addr;
        num_of_dequeue_bits = '0;
        num_of_enqueue_bits = '0;

        if(tail_addr < head_addr) begin
            elemcount = (DEPTH_BITS+1)'(head_addr - tail_addr);
        end else if(tail_addr > head_addr) begin
            elemcount = DEPTH - (tail_addr - head_addr);
        end else begin
            elemcount = could_be_empty ? '0 : DEPTH;
        end
        freespace = DEPTH - elemcount;

        for(l = 0; l < DEPTH_N; l++) begin
            cdb_mapping[l] = '0;
        end

        for(count_idx = 0; count_idx < CDB_COUNT; count_idx++) begin
            if(cdb[count_idx].ready) begin
                cdb_mapping[cdb[count_idx].rob_id] = cdb[count_idx];
            end
        end

        for(count_idx = 0; count_idx < NSIZE; count_idx++) begin
            num_of_dequeue_bits += (NSIZE_BITS+1)'(dequeue[count_idx]);
            num_of_enqueue_bits += (NSIZE_BITS+1)'(enqueue[count_idx]);
        end

        Qmem_write_m = '{default: '0};

        for (j = 0; j < NSIZE; j++) begin
            rob_id_to_insert[j] = head_addr + DEPTH_BITS'(j); 
            Qmem_m[j] = 'x;
            if((DEPTH_BITS + 1)'(j) < elemcount) begin
                dout[j] = Qmem[tail_addr + DEPTH_BITS'(j)];
            end else begin
                dout[j] = 'x;
                dout[j].ready = '0;
            end

            if(enqueue[j]) begin
                Qmem_m[j] = din[j];
                Qmem_write_m[head_addr + DEPTH_BITS'(j)] = (NSIZE+1)'(j + 1);
            end
        end
    end

endmodule
