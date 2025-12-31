module load_store_logic
import rv32i_types::*;
#(
    parameter                   ROB_DEPTH_BITS = 4,
    parameter                   DEPTH_BITS = 3,
    parameter                   DEPTH_N = 2 ** DEPTH_BITS,
    parameter                   NSIZE = 1,
    localparam                  NSIZE_BITS = $clog2(NSIZE),
    parameter                   CDB_COUNT  = 1
)(
    input   rst,
    input   clk,
    
    input   rob_flush,
    
    // load store queue ports
    output  logic   [NSIZE-1:0]         lsq_dequeue,
    input   lsq_entry_t                 lsq_dout[NSIZE],
    input   logic   [DEPTH_BITS:0]      lsq_elemcount,
    
    // dcache ports
    output   logic   [31:0]  data_ufp_addr,
    output   logic   [3:0]   data_ufp_rmask,
    output   logic   [3:0]   data_ufp_wmask,
    input    logic   [31:0]  data_ufp_rdata,
    output   logic   [31:0]  data_ufp_wdata,
    input    logic           data_ufp_resp,
    
    // CDB ports
    input   logic                       cdb_busy,
    output  cdb_t                       cdb,
    
    // ROB ports
    input  logic   [ROB_DEPTH_BITS:0]   rob_elemcount,
    input  logic unsigned [ROB_DEPTH_BITS-1:0] rob_current_tail_addr,
    
    // Commit logic ports
    output logic                        store_done,
    output logic [31:0]                 store_monitor_mem_wdata,
    output logic [3:0]                  store_monitor_mem_wmask,
    output logic [31:0]                 store_monitor_mem_addr,
    output logic [31:0]                 store_monitor_rs1_rdata,
    output logic [31:0]                 store_monitor_rs2_rdata
);

logic invalidate_resp;

always_ff @(posedge clk) begin
    if(rst) begin
        invalidate_resp <= '0;
    end else if(rob_flush) begin
        invalidate_resp <= '1;
    end else if(data_ufp_resp) begin
        invalidate_resp <= '0;
    end
end

always_comb begin
    // Data Cache logic
    data_ufp_addr = 'x;
    data_ufp_rmask = '0;
    data_ufp_wmask = '0;
    data_ufp_wdata = 'x;
    if((!data_ufp_resp || invalidate_resp) && lsq_elemcount != '0 && rob_elemcount != '0 && lsq_dout[0].ready) begin
        if(lsq_dout[0].is_load) begin
            data_ufp_addr = {lsq_dout[0].addr[31:2], 2'b00};
            data_ufp_rmask = lsq_dout[0].mask;
        end else if(rob_current_tail_addr == lsq_dout[0].rob_id) begin // Store cant happen until it is at the head of the ROB
            data_ufp_addr = {lsq_dout[0].addr[31:2], 2'b00};
            data_ufp_wmask = lsq_dout[0].mask;
            data_ufp_wdata = lsq_dout[0].wdata;
        end
    end
    
    cdb.ready = '0;
    cdb.rob_id = 'x;
    cdb.ar_dest = 'x;
    cdb.pr_dest = 'x;
    cdb.result = 'x;
    cdb.monitor_rs1_rdata = 'x;
    cdb.monitor_rs2_rdata = 'x;
    cdb.monitor_mem_rdata = 'x;
    cdb.monitor_mem_rmask = '0;
    cdb.monitor_mem_addr  = 'x;
    lsq_dequeue = '0;
    if(data_ufp_resp && !invalidate_resp && lsq_dout[0].is_load && lsq_dout[0].ready && lsq_elemcount != '0 && rob_elemcount != '0) begin
        if(cdb_busy) begin // Keep reading from the cache until it isnt busy (if its already in cache, future reads will only take a cycle)
            data_ufp_addr = {lsq_dout[0].addr[31:2], 2'b00};
            data_ufp_rmask = '1;
        end else begin
            cdb.ready = '1;
            cdb.rob_id = lsq_dout[0].rob_id;
            cdb.ar_dest = lsq_dout[0].ar_dest;
            cdb.pr_dest = lsq_dout[0].pr_dest;
            unique case (lsq_dout[0].funct3)
                load_f3_lb : cdb.result = {{24{data_ufp_rdata[7 +8 *lsq_dout[0].addr[1:0]]}}, data_ufp_rdata[8 *lsq_dout[0].addr[1:0] +: 8 ]};
                load_f3_lbu: cdb.result = {{24{1'b0}}                                      , data_ufp_rdata[8 *lsq_dout[0].addr[1:0] +: 8 ]};
                load_f3_lh : cdb.result = {{16{data_ufp_rdata[15+16*lsq_dout[0].addr[1]  ]}}, data_ufp_rdata[16*lsq_dout[0].addr[1]   +: 16]};
                load_f3_lhu: cdb.result = {{16{1'b0}}                                      , data_ufp_rdata[16*lsq_dout[0].addr[1]   +: 16]};
                load_f3_lw : cdb.result = data_ufp_rdata;
                default    : cdb.result = 'x;
            endcase
            cdb.monitor_rs1_rdata = lsq_dout[0].monitor_rs1_rdata;
            cdb.monitor_rs2_rdata = lsq_dout[0].monitor_rs2_rdata;
            cdb.monitor_mem_rdata = data_ufp_rdata;
            cdb.monitor_mem_rmask = lsq_dout[0].mask;
            cdb.monitor_mem_addr  = {lsq_dout[0].addr[31:2], 2'b00};
            lsq_dequeue[0] = '1;
        end
    end
    
    store_done = '0;
    store_monitor_mem_wdata = 'x;
    store_monitor_mem_wmask = '0;
    store_monitor_mem_addr = 'x;
    store_monitor_rs1_rdata = 'x;
    store_monitor_rs2_rdata = 'x;
    
    if(data_ufp_resp && !invalidate_resp && !lsq_dout[0].is_load && lsq_dout[0].ready && lsq_elemcount != '0 && rob_elemcount != '0) begin
        store_done = '1;
        store_monitor_mem_wdata = lsq_dout[0].wdata;
        store_monitor_mem_wmask = lsq_dout[0].mask;
        store_monitor_mem_addr  = {lsq_dout[0].addr[31:2], 2'b00};
        store_monitor_rs1_rdata = lsq_dout[0].monitor_rs1_rdata;
        store_monitor_rs2_rdata = lsq_dout[0].monitor_rs2_rdata;
        lsq_dequeue[0] = '1;
    end
end

endmodule : load_store_logic
