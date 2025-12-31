module commit_logic
import rv32i_types::*;
#(
            parameter                   ROB_DEPTH_BITS = 8,
            parameter                   NSIZE = 1,
            localparam                  NSIZE_BITS = $clog2(NSIZE),
            parameter       logic[3:0]  NSIZE_SMALL = 2 ** NSIZE_BITS,
            parameter                   PR_BITS = 6,
            parameter                   FL_DEPTH_BITS = 6,
            parameter                   BQ_DEPTH_BITS = 4
) (
    input  rob_entry_t                  rob_dout[NSIZE],
    input  logic   [ROB_DEPTH_BITS:0]   rob_elemcount,
    output logic   [NSIZE-1:0]          rob_dequeue,
    output logic                        rob_flush,
    output logic   [BQ_DEPTH_BITS:0]    branch_taken_location,

    input   logic   [PR_BITS-1:0]       rrf_alias_pd_old[NSIZE],
    output  logic   [4:0]               rrf_alias_rd[NSIZE],
    output  logic   [PR_BITS-1:0]       rrf_alias_pd[NSIZE],
    output  logic                       rrf_alias_regf_we[NSIZE],

    input   logic   [FL_DEPTH_BITS:0]   fl_freespace,
    output  logic   [PR_BITS-1:0]       fl_din[NSIZE],
    output  logic   [NSIZE-1:0]         fl_enqueue,

    input   bq_entry_t                  bq_dout[NSIZE],
    output  logic   [NSIZE-1:0]         bq_dequeue,
    
    // Special path for store instructions
    input logic                        store_done,
    input logic [31:0]                 store_monitor_mem_wdata,
    input logic [3:0]                  store_monitor_mem_wmask,
    input logic [31:0]                 store_monitor_mem_addr,
    input logic [31:0]                 store_monitor_rs1_rdata,
    input logic [31:0]                 store_monitor_rs2_rdata
);
    logic         monitor_valid    [8];
    logic [63:0]  monitor_order    [8];
    logic [31:0]  monitor_inst     [8];
    logic [4:0]   monitor_rs1_addr [8];
    logic [4:0]   monitor_rs2_addr [8];
    logic [31:0]  monitor_rs1_rdata[8];
    logic [31:0]  monitor_rs2_rdata[8];
    logic         monitor_regf_we  [8];
    logic [4:0]   monitor_frd_addr [8];
    logic [31:0]  monitor_frd_wdata[8];
    logic [4:0]   monitor_rd_addr  [8];
    logic [31:0]  monitor_rd_wdata [8];
    logic [31:0]  monitor_pc_rdata [8];
    logic [31:0]  monitor_pc_wdata [8];
    logic [31:0]  monitor_mem_addr [8];
    logic [3:0]   monitor_mem_rmask[8];
    logic [3:0]   monitor_mem_wmask[8];
    logic [31:0]  monitor_mem_rdata[8];
    logic [31:0]  monitor_mem_wdata[8];

    logic  [6:0]  inst_opcode;
    logic  [FL_DEPTH_BITS:0] fl_added;
    logic  [BQ_DEPTH_BITS:0] bq_removed;

    always_comb begin
        fl_added = '0;
        bq_removed = '0;
        rob_dequeue = '0;
        fl_enqueue = '0;
        rob_flush = '0;
        bq_dequeue = '0;
        branch_taken_location = 'x;
        
        // Unused
		if(fl_freespace != '0) begin end

        for(integer i = 0; i < 8; i++) begin
            monitor_valid[i] = '0;

            monitor_order[i]     =   'x; 
            monitor_inst[i]      =   'x; 
            monitor_rs1_addr[i]  =   'x; 
            monitor_rs2_addr[i]  =   'x; 
            monitor_rs1_rdata[i] =   'x; 
            monitor_rs2_rdata[i] =   'x; 
            monitor_regf_we[i]   =   'x; 
            monitor_rd_addr[i]   =   'x; 
            monitor_rd_wdata[i]  =   'x; 
            monitor_pc_rdata[i]  =   'x; 
            monitor_pc_wdata[i]  =   'x; 
            monitor_mem_addr[i]  =   'x; 
            monitor_mem_rmask[i] =   'x; 
            monitor_mem_wmask[i] =   'x; 
            monitor_mem_rdata[i] =   'x; 
            monitor_mem_wdata[i] =   'x; 
            
            // Floating point stuff
            monitor_frd_addr[i]  =     'x;
            monitor_frd_wdata[i] =     'x;
        end
        
        for(int unsigned i = 0; i < NSIZE; i++) begin
            rrf_alias_rd[i] = 'x;
            rrf_alias_pd[i] = 'x;
            rrf_alias_regf_we[i] = '0;
            
            fl_din[i] = 'x;
        end

        for(int unsigned i = 0; i < NSIZE; i++) begin
            inst_opcode = rob_dout[i].monitor_inst[6:0];
            if(rob_elemcount > (ROB_DEPTH_BITS+1)'(i) && rob_dout[i].ready && inst_opcode != op_b_store) begin
                rrf_alias_rd[i] = rob_dout[i].monitor_rd_addr;
                rrf_alias_pd[i] = rob_dout[i].pr_dest;
                rrf_alias_regf_we[i] = '1;
                // If the mapping is different, and we arent looking at register
                // 0, queue the register to the back of the free list
                if(rrf_alias_pd_old[i] != rob_dout[i].pr_dest && rob_dout[i].monitor_rd_addr != '0) begin
                    fl_din[fl_added] = rrf_alias_pd_old[i];
                    fl_enqueue[fl_added] = '1;
                    fl_added = fl_added + (FL_DEPTH_BITS + 1)'(1);
                end
                rob_dequeue[i] = '1;
            
                if(inst_opcode == op_b_jal || inst_opcode == op_b_jalr || inst_opcode == op_b_br) begin
                    if(bq_dout[bq_removed].branch_taken) begin
                        rob_flush = '1;
                        branch_taken_location = bq_removed;
                    end
                    bq_dequeue[bq_removed] = '1;
                end
            
                monitor_valid[i]     =     '1;
                monitor_order[i]     =     rob_dout[i].monitor_order;
                monitor_inst[i]      =     rob_dout[i].monitor_inst;
                monitor_rs1_addr[i]  =     rob_dout[i].monitor_rs1_addr;
                monitor_rs2_addr[i]  =     rob_dout[i].monitor_rs2_addr;
                monitor_rs1_rdata[i] =     rob_dout[i].monitor_rs1_rdata;
                monitor_rs2_rdata[i] =     rob_dout[i].monitor_rs2_rdata;
                monitor_regf_we[i]   =     rob_dout[i].monitor_regf_we;
                monitor_rd_addr[i]   =     rob_dout[i].monitor_rd_addr;
                monitor_rd_wdata[i]  =     rob_dout[i].monitor_rd_wdata;
                monitor_pc_rdata[i]  =     rob_dout[i].monitor_pc_rdata;
                monitor_pc_wdata[i]  =     rob_flush ? bq_dout[bq_removed].branch_target : rob_dout[i].monitor_pc_wdata;
                monitor_mem_addr[i]  =     rob_dout[i].monitor_mem_addr;
                monitor_mem_rmask[i] =     rob_dout[i].monitor_mem_rmask;
                monitor_mem_wmask[i] =     rob_dout[i].monitor_mem_wmask;
                monitor_mem_rdata[i] =     rob_dout[i].monitor_mem_rdata;
                monitor_mem_wdata[i] =     rob_dout[i].monitor_mem_wdata;
                
                // Floating point stuff
                monitor_frd_addr[i]  =     'x;
                monitor_frd_wdata[i] =     'x;
                
                
                if(inst_opcode == op_b_jal || inst_opcode == op_b_jalr || inst_opcode == op_b_br)
                    bq_removed = bq_removed + (BQ_DEPTH_BITS + 1)'(1);
                if(rob_flush)
                    break;
                    
            end else if(rob_elemcount > (ROB_DEPTH_BITS+1)'(i) && i == '0 && store_done) begin
                rrf_alias_rd[i] = rob_dout[i].monitor_rd_addr;
                rrf_alias_pd[i] = rob_dout[i].pr_dest;
                rrf_alias_regf_we[i] = '1;
                // If the mapping is different, and we arent looking at register
                // 0, queue the register to the back of the free list
                if(rrf_alias_pd_old[i] != rob_dout[i].pr_dest && rob_dout[i].monitor_rd_addr != '0) begin
                    fl_din[fl_added] = rrf_alias_pd_old[i];
                    fl_enqueue[fl_added] = '1;
                    fl_added = fl_added + (FL_DEPTH_BITS + 1)'(1);
                end
                rob_dequeue[i] = '1;
            
                monitor_valid[i]     =     '1;
                monitor_order[i]     =     rob_dout[i].monitor_order;
                monitor_inst[i]      =     rob_dout[i].monitor_inst;
                monitor_rs1_addr[i]  =     rob_dout[i].monitor_rs1_addr;
                monitor_rs2_addr[i]  =     rob_dout[i].monitor_rs2_addr;
                monitor_rs1_rdata[i] =     store_monitor_rs1_rdata;
                monitor_rs2_rdata[i] =     store_monitor_rs2_rdata;
                monitor_regf_we[i]   =     '0;
                monitor_rd_addr[i]   =     '0;
                monitor_rd_wdata[i]  =     'x;
                monitor_pc_rdata[i]  =     rob_dout[i].monitor_pc_rdata;
                monitor_pc_wdata[i]  =     rob_dout[i].monitor_pc_wdata;
                monitor_mem_addr[i]  =     store_monitor_mem_addr;
                monitor_mem_rmask[i] =     '0;
                monitor_mem_wmask[i] =     store_monitor_mem_wmask;
                monitor_mem_rdata[i] =     'x;
                monitor_mem_wdata[i] =     store_monitor_mem_wdata;
                
                // Floating point stuff
                monitor_frd_addr[i]  =     'x;
                monitor_frd_wdata[i] =     'x;           
            end else begin
                break;
            end
        end
    end
endmodule : commit_logic
