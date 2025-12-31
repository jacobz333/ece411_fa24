module load_store_queue 
import rv32i_types::*;
#(
    parameter                   DEPTH_BITS = 3,
    parameter                   DEPTH_N = 2 ** DEPTH_BITS,
    parameter                   NSIZE = 1,
    localparam                  NSIZE_BITS = $clog2(NSIZE)
)(
    input   logic                       clk,
    input   logic                       rst,
    input   lsq_entry_t                 din[NSIZE],
    input   logic   [NSIZE-1:0]         enqueue,
    input   logic   [NSIZE-1:0]         dequeue,
    input   lsq_bus_t                   bus,
    output  lsq_entry_t                 dout[NSIZE],
    output  logic   [DEPTH_BITS-1:0]    lsq_id_to_insert[NSIZE],
    output  logic   [DEPTH_BITS:0]      freespace,
    output  logic   [DEPTH_BITS:0]      elemcount
);

    localparam          [DEPTH_BITS:0]     DEPTH       = 2 ** DEPTH_BITS;

    lsq_entry_t                            Qmem[DEPTH];

    logic               [NSIZE_BITS:0]     num_of_dequeue_bits;
    logic               [NSIZE_BITS:0]     num_of_enqueue_bits;

    logic   unsigned    [DEPTH_BITS-1:0]   head_addr;
    logic   unsigned    [DEPTH_BITS-1:0]   tail_addr;

    lsq_entry_t                            Qmem_m[NSIZE];
    logic               [NSIZE:0]          Qmem_write_m[DEPTH];

    lsq_bus_t                              bus_mapping[DEPTH];

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
        end
    end

    generate for(genvar i = 0; i < DEPTH_N; i++) begin : rob_block_b
        always_ff @(posedge clk) begin
            if(rst) begin
                Qmem[i] <= 'x;
                Qmem[i].ready <= '0;
            end else if(Qmem_write_m[i] != '0) begin
                
                //ifdef LOAD_STORE_QUEUE_N_ONE
                //    Qmem[i] <= Qmem_m[0];
                //else
                    Qmem[i] <= Qmem_m[(NSIZE_BITS)'(32'(Qmem_write_m[i]) - (32)'(1))];
                //endif
            end else if(bus_mapping[i].ready) begin
                Qmem[i].ready <= 1'b1;
                Qmem[i].mask <= bus_mapping[i].mask;
                Qmem[i].addr <= bus_mapping[i].addr;
                Qmem[i].wdata <= bus_mapping[i].wdata;
                Qmem[i].monitor_rs1_rdata <= bus_mapping[i].monitor_rs1_rdata;
                Qmem[i].monitor_rs2_rdata <= bus_mapping[i].monitor_rs2_rdata;
            end
        end
    end endgenerate
  
    always_comb begin
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
            bus_mapping[l] = '0;
        end

        bus_mapping[bus.lsq_id] = bus;

        for(count_idx = 0; count_idx < NSIZE; count_idx++) begin
            num_of_dequeue_bits += (NSIZE_BITS+1)'(dequeue[count_idx]);
            num_of_enqueue_bits += (NSIZE_BITS+1)'(enqueue[count_idx]);
        end

        Qmem_write_m = '{default: '0};

        for (j = 0; j < NSIZE; j++) begin
            lsq_id_to_insert[j] = head_addr + DEPTH_BITS'(j);
            Qmem_m[j] = 'x;
            Qmem_m[j].ready = '0;
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
