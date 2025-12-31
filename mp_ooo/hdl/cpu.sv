module cpu
import rv32i_types::*;
(
    input   logic               clk,
    input   logic               rst,

    output  logic   [31:0]      bmem_addr,
    output  logic               bmem_read,
    output  logic               bmem_write,
    output  logic   [63:0]      bmem_wdata,
    input   logic               bmem_ready,

    input   logic   [31:0]      bmem_raddr,
    input   logic   [63:0]      bmem_rdata,
    input   logic               bmem_rvalid
);
    localparam NSIZE_INSTRUCTIONS_BITS = $clog2(CONST_NSIZE_INSTRUCTIONS);
    localparam NSIZE_INSTRUCTIONS = CONST_NSIZE_INSTRUCTIONS;
    
    localparam NSIZE_BITS = $clog2(CONST_NSIZE); // super scalar
    localparam NSIZE = CONST_NSIZE;
    localparam IQSIZE_BITS = CONST_IQSIZE_BITS;
    localparam ROBSIZE_BITS = CONST_ROBSIZE_BITS;
    localparam PR_BITS = CONST_PR_BITS;
    localparam LSQSIZE_BITS = CONST_LSQSIZE_BITS;
    // TODO: This is problamatic. FL_SIZE should be PR_SIZE - 32 (ARCH_SIZE), say
    // with 128 PR and 32 AR, FL SIZE is 96 and BITS is 7. 
    // but if we hold PR_SIZE static this won't affect anything. 
    localparam FLSIZE_BITS = PR_BITS-1; 
    localparam BQSIZE_BITS = CONST_BQSIZE_BITS;
    localparam RSSIZE_BITS = CONST_RSSIZE_BITS;
    
    // Sum of execution units doesnt have to be equal to N, but it should be at least N
    localparam COMPUTE_BASE_COUNT = 2;
    localparam COMPUTE_MUL_COUNT = 2;
    localparam COMPUTE_DIV_COUNT = 2;
    localparam COMPUTE_BRANCH_COUNT = 1; // Cant change yet
    localparam COMPUTE_LS_COUNT = 1; // Cant change yet
    localparam COMPUTE_OUT_COUNT = COMPUTE_BASE_COUNT + COMPUTE_MUL_COUNT + COMPUTE_DIV_COUNT + COMPUTE_BRANCH_COUNT + COMPUTE_LS_COUNT;
    localparam CDB_COUNT = COMPUTE_OUT_COUNT;
    localparam READ_PORT_NUM = COMPUTE_OUT_COUNT;

    iq_entry_t                  iq_din[NSIZE_INSTRUCTIONS];
    logic   [NSIZE_INSTRUCTIONS-1:0]         iq_enqueue;
    logic   [NSIZE_INSTRUCTIONS-1:0]         iq_dequeue;
    iq_entry_t                  iq_dout[NSIZE_INSTRUCTIONS];
    logic   [IQSIZE_BITS:0]     iq_freespace;
    logic   [IQSIZE_BITS:0]     iq_elemcount;

    logic   [4:0]             rat_alias_rd[NSIZE];
    logic   [PR_BITS-1:0]     rat_alias_pd[NSIZE];
    logic                     rat_alias_regf_we[NSIZE];
    logic   [4:0]             rat_alias_rs1[NSIZE];
    logic   [PR_BITS-1:0]     rat_alias_ps1[NSIZE];
    logic                     rat_alias_ps1_valid[NSIZE];
    logic   [4:0]             rat_alias_rs2[NSIZE];
    logic   [PR_BITS-1:0]     rat_alias_ps2[NSIZE];
    logic                     rat_alias_ps2_valid[NSIZE];

    rob_entry_t                 rob_din[NSIZE];
    logic   [NSIZE-1:0]         rob_enqueue;
    logic   [NSIZE-1:0]         rob_dequeue;
    rob_entry_t                 rob_dout[NSIZE];
    logic   [ROBSIZE_BITS-1:0]  rob_rob_id_to_insert[NSIZE];
    logic   [ROBSIZE_BITS:0]    rob_freespace;
    logic   [ROBSIZE_BITS:0]    rob_elemcount;
    logic unsigned  [ROBSIZE_BITS-1:0]  rob_current_tail_addr;
    logic                       rob_flush;
    
    logic   [BQSIZE_BITS:0]     branch_taken_location;
    
    logic   [4:0]             rrf_alias_rd        [NSIZE];
    logic   [PR_BITS-1:0]     rrf_alias_pd        [NSIZE];
    logic                     rrf_alias_regf_we   [NSIZE];
    logic   [PR_BITS-1:0]     rrf_alias_pd_old    [NSIZE];

    logic   [PR_BITS-1:0]       fl_din[NSIZE];
    logic   [NSIZE-1:0]         fl_enqueue;
    logic   [NSIZE-1:0]         fl_dequeue;
    logic   [PR_BITS-1:0]       fl_dout[NSIZE];
    logic   [FLSIZE_BITS:0]     fl_freespace;
    logic   [FLSIZE_BITS:0]     fl_elemcount;

    // register file ports
    logic                   regf_we;
    logic   [PR_BITS-1:0]   regf_pd_addr;
    logic   [31:0]          regf_pd_wdata;
    logic   [PR_BITS-1:0]   regf_ps1_addr[READ_PORT_NUM];
    logic   [PR_BITS-1:0]   regf_ps2_addr[READ_PORT_NUM];
    logic   [31:0]          regf_ps1_data[READ_PORT_NUM];
    logic   [31:0]          regf_ps2_data[READ_PORT_NUM];

    logic   [31:0]  icache_ufp_addr;
    logic   [3:0]   icache_ufp_rmask;
    logic   [3:0]   icache_ufp_wmask;
    logic   [255:0] icache_ufp_rdata;
    logic   [31:0]  icache_ufp_wdata;
    logic           icache_ufp_resp;
    logic   [31:0]  icache_dfp_addr;
    logic           icache_dfp_read;
    logic           icache_dfp_write;
    logic   [255:0] icache_dfp_rdata;
    logic   [255:0] icache_dfp_wdata;
    logic           icache_dfp_resp;
    
    logic   [31:0]  dcache_ufp_addr;
    logic   [3:0]   dcache_ufp_rmask;
    logic   [3:0]   dcache_ufp_wmask;
    logic   [31:0]  dcache_ufp_rdata;
    logic   [31:0]  dcache_ufp_wdata;
    logic           dcache_ufp_resp;
    logic   [31:0]  dcache_dfp_addr;
    logic           dcache_dfp_read;
    logic           dcache_dfp_write;
    logic   [255:0] dcache_dfp_rdata;
    logic   [255:0] dcache_dfp_wdata;
    logic           dcache_dfp_resp;
    
    lsq_entry_t                 lsq_din[NSIZE]             ;
    logic   [NSIZE-1:0]         lsq_enqueue                ;
    logic   [NSIZE-1:0]         lsq_dequeue                ;
    lsq_bus_t                   lsq_bus                    ;
    lsq_entry_t                 lsq_dout[NSIZE]            ;
    logic   [LSQSIZE_BITS-1:0]  lsq_lsq_id_to_insert[NSIZE];
    logic   [LSQSIZE_BITS:0]    lsq_freespace              ;
    logic   [LSQSIZE_BITS:0]    lsq_elemcount              ;

    bq_entry_t                 bq_din[NSIZE]            ;
    logic   [NSIZE-1:0]        bq_enqueue               ;
    logic   [NSIZE-1:0]        bq_dequeue               ;
    bq_bus_t                   bq_bus                   ;
    bq_entry_t                 bq_dout[NSIZE]           ;
    logic   [BQSIZE_BITS-1:0]  bq_bq_id_to_insert[NSIZE];
    logic   [BQSIZE_BITS:0]    bq_freespace             ;
    logic   [BQSIZE_BITS:0]    bq_elemcount             ;
    
    logic                       ls_logic_cdb_busy;
    
    logic                       ls_logic_store_done;
    logic [31:0]                ls_logic_store_monitor_mem_wdata;
    logic [3:0]                 ls_logic_store_monitor_mem_wmask;
    logic [31:0]                ls_logic_store_monitor_mem_addr;
    logic [31:0]                ls_logic_store_monitor_rs1_rdata;
    logic [31:0]                ls_logic_store_monitor_rs2_rdata;
    
    logic       [RSSIZE_BITS:0]   rs_freespace;
    logic       [NSIZE-1:0]       rs_enqueue;
    rs_entry_t                    rs_entry_din[NSIZE];
    
    cdb_t global_cdb[CDB_COUNT];

    logic   [31:0]  PC, PC_next;
    logic   [63:0]  order;

    logic  [PR_BITS-1:0]     alias_mem       [32];
    
    logic fetch_logic_move_pc;
    logic [3:0] fetch_logic_move_amount;

    logic                           base_alu_rs_entry_valid[COMPUTE_BASE_COUNT];
    rs_entry_t                      base_alu_rs_entry_dout[COMPUTE_BASE_COUNT];
    logic                           base_alu_ready[COMPUTE_BASE_COUNT];
    logic                           base_alu_stall;

    logic                           mul_alu_rs_entry_valid[COMPUTE_MUL_COUNT];
    rs_entry_t                      mul_alu_rs_entry_dout[COMPUTE_MUL_COUNT];
    logic                           div_alu_rs_entry_valid[COMPUTE_DIV_COUNT];
    rs_entry_t                      div_alu_rs_entry_dout[COMPUTE_DIV_COUNT];
    logic                           mul_alu_ready[COMPUTE_MUL_COUNT];
    logic                           div_alu_ready[COMPUTE_DIV_COUNT];
    logic                           mul_stall;
    logic                           div_stall;

    logic                           load_store_calculator_rs_entry_valid[COMPUTE_LS_COUNT];
    rs_entry_t                      load_store_calculator_rs_entry_dout[COMPUTE_LS_COUNT];
    logic                           load_store_calculator_ready[COMPUTE_LS_COUNT];

    logic                           branch_alu_rs_entry_valid[COMPUTE_BRANCH_COUNT];
    rs_entry_t                      branch_alu_rs_entry_dout[COMPUTE_BRANCH_COUNT];
    logic                           branch_alu_ready[COMPUTE_BRANCH_COUNT];
    logic                           branch_stall;
    
    PC PC_i (
        .clk,
        .rst,
        .move_pc    (fetch_logic_move_pc),
        .move_amount(fetch_logic_move_amount),
        .Br_PC      (bq_dout[branch_taken_location].branch_target),
        .Br_order   (bq_dout[branch_taken_location].branch_order),
        .Br_valid   ((bq_elemcount > branch_taken_location) && bq_dout[branch_taken_location].branch_taken && rob_flush),
        .PC,
        .PC_next,
        .order
    );

    fetch_logic #(
        .DEPTH_BITS(IQSIZE_BITS), 
        .NSIZE(NSIZE_INSTRUCTIONS)
    ) fetch_logic_i (
        .clk,
        .rst(rst),
        .rob_flush(rob_flush),
        .icache_ufp_addr(icache_ufp_addr),
        .icache_ufp_rmask(icache_ufp_rmask),
        .icache_ufp_wmask(icache_ufp_wmask),
        .icache_ufp_rdata(icache_ufp_rdata),
        .icache_ufp_wdata(icache_ufp_wdata),
        .icache_ufp_resp(icache_ufp_resp),
        .move_pc(fetch_logic_move_pc),
        .move_amount(fetch_logic_move_amount),
        .enqueue(iq_enqueue),
        .instructions(iq_din),
        .freespace(iq_freespace),
        .PC,
        .PC_next,
        .order
    );
    
    instruction_queue #(
        .DEPTH_BITS(IQSIZE_BITS), 
        .NSIZE(NSIZE_INSTRUCTIONS)
    ) instruction_queue_i (
        .clk,
        .rst(rst | rob_flush),
        .din(iq_din),
        .enqueue(iq_enqueue),
        .dequeue(iq_dequeue),
        .dout(iq_dout),
        .freespace(iq_freespace),
        .elemcount(iq_elemcount)
    );

    rob #(
        .DEPTH_BITS(ROBSIZE_BITS), 
        .NSIZE(NSIZE), 
        .CDB_COUNT(CDB_COUNT)
    ) rob_i (
        .clk,
        .rst(rst | rob_flush),
        .din(rob_din),
        .enqueue(rob_enqueue),
        .dequeue(rob_dequeue),
        .cdb(global_cdb),
        .dout(rob_dout),
        .rob_id_to_insert(rob_rob_id_to_insert),
        .freespace(rob_freespace),
        .elemcount(rob_elemcount),
        .current_tail_addr(rob_current_tail_addr),
        .flush(rob_flush)
    );
    
    dispatch_logic #(
        .ROBSIZE_BITS(ROBSIZE_BITS), 
        .LSQSIZE_BITS(LSQSIZE_BITS), 
        .RSSIZE_BITS(RSSIZE_BITS), 
        .BQSIZE_BITS(BQSIZE_BITS), 
        .NSIZE_INSTRUCTIONS(NSIZE_INSTRUCTIONS), 
        .NSIZE(NSIZE), 
        .PR_BITS(PR_BITS), 
        .FL_DEPTH_BITS(FLSIZE_BITS), 
        .IQ_DEPTH_BITS(IQSIZE_BITS)
    ) dispatch_logic_i (
        .rob_din,
        .rob_freespace,
        .rob_enqueue,
        .rob_rob_id_to_insert,

        .iq_dout,
        .iq_elemcount,
        .iq_dequeue,
        
        .lsq_din,
        .lsq_freespace,
        .lsq_enqueue,
        .lsq_lsq_id_to_insert,

        .bq_din,
        .bq_freespace,
        .bq_enqueue,
        .bq_bq_id_to_insert,
    
        .rat_alias_rd,
        .rat_alias_pd,
        .rat_alias_regf_we,
        .rat_alias_rs1,
        .rat_alias_ps1,
        .rat_alias_ps1_valid,
        .rat_alias_rs2, 
        .rat_alias_ps2,      
        .rat_alias_ps2_valid,

        .fl_elemcount,
        .fl_dout,
        .fl_dequeue,

        .rs_freespace,
        .rs_enqueue,
        .rs_entry_din
    );

    free_list #(
        .WIDTH(PR_BITS), 
        .DEPTH_BITS(FLSIZE_BITS), 
        .NSIZE(NSIZE)
    ) fl_queue_i (
        .clk,
        .rst,
        .din(fl_din),
        .enqueue(fl_enqueue),
        .dequeue(fl_dequeue),
        .dout(fl_dout),
        .freespace(fl_freespace),
        .elemcount(fl_elemcount),
        .rob_flush
    );

    RAT_n #(
        .PHYS_BITS(PR_BITS), 
        .CDB_COUNT(CDB_COUNT), 
        .NSIZE(NSIZE)
    ) rat_i (
        .clk,
        .rst,

        .alias_rd(rat_alias_rd),
        .alias_pd(rat_alias_pd),
        .alias_regf_we(rat_alias_regf_we),
        .alias_rs1(rat_alias_rs1),
        .alias_ps1(rat_alias_ps1),
        .alias_ps1_valid(rat_alias_ps1_valid),
        .alias_rs2(rat_alias_rs2),
        .alias_ps2(rat_alias_ps2),
        .alias_ps2_valid(rat_alias_ps2_valid),

        .global_cdb(global_cdb), 

        .RRF_in(alias_mem),
        .rrf_alias_rd,
        .rrf_alias_pd,
        .rrf_alias_regf_we,
        .rob_flush
    );

    commit_logic #(
        .PR_BITS(PR_BITS), 
        .FL_DEPTH_BITS(FLSIZE_BITS), 
        .NSIZE(NSIZE), 
        .ROB_DEPTH_BITS(ROBSIZE_BITS), 
        .BQ_DEPTH_BITS(BQSIZE_BITS)
    ) commit_logic_i (
        .rob_dout,
        .rob_elemcount,
        .rob_dequeue,
        .rob_flush,
        .branch_taken_location,

        .rrf_alias_pd_old,
        .rrf_alias_rd,
        .rrf_alias_pd,
        .rrf_alias_regf_we,

        .fl_freespace,
        .fl_din,
        .fl_enqueue,

        .bq_dout,
        .bq_dequeue,
        
        .store_done             (ls_logic_store_done             ),
        .store_monitor_mem_wdata(ls_logic_store_monitor_mem_wdata),
        .store_monitor_mem_wmask(ls_logic_store_monitor_mem_wmask),
        .store_monitor_mem_addr (ls_logic_store_monitor_mem_addr ),
        .store_monitor_rs1_rdata(ls_logic_store_monitor_rs1_rdata),
        .store_monitor_rs2_rdata(ls_logic_store_monitor_rs2_rdata)
    );

    RRF_n #(
        .PHYS_BITS(PR_BITS), 
        .NSIZE(NSIZE)
    ) rrf_i (
        .clk,
        .rst,

        .alias_rd(rrf_alias_rd),
        .alias_pd(rrf_alias_pd),
        .alias_regf_we(rrf_alias_regf_we),
        .alias_pd_old(rrf_alias_pd_old),
        .alias_mem
    );

    regfile #(
        .PR_BITS(PR_BITS), 
        .READ_PORT_NUM(COMPUTE_OUT_COUNT), 
        .CDB_COUNT(CDB_COUNT)
    ) phys_regfile (
        .clk,
        .rst,
        .cdb(global_cdb),
        .ps1_addr(regf_ps1_addr),
        .ps2_addr(regf_ps2_addr),
        .ps1_data(regf_ps1_data),
        .ps2_data(regf_ps2_data)
    );
    
    instruction_cache icache (
        .clk,
        .rst,
        
        .ufp_addr (icache_ufp_addr ),
        .ufp_rmask(icache_ufp_rmask),
        .ufp_wmask(icache_ufp_wmask),
        .ufp_rdata(icache_ufp_rdata),
        .ufp_wdata(icache_ufp_wdata),
        .ufp_resp (icache_ufp_resp ),
        
        .dfp_addr (icache_dfp_addr ),
        .dfp_read (icache_dfp_read ),
        .dfp_write(icache_dfp_write),
        .dfp_rdata(icache_dfp_rdata),
        .dfp_wdata(icache_dfp_wdata),
        .dfp_resp (icache_dfp_resp )
    );
     
    data_cache dcache (
        .clk,
        .rst,
        
        .ufp_addr (dcache_ufp_addr ),
        .ufp_rmask(dcache_ufp_rmask),
        .ufp_wmask(dcache_ufp_wmask),
        .ufp_rdata(dcache_ufp_rdata),
        .ufp_wdata(dcache_ufp_wdata),
        .ufp_resp (dcache_ufp_resp ),
        
        .dfp_addr (dcache_dfp_addr ),
        .dfp_read (dcache_dfp_read ),
        .dfp_write(dcache_dfp_write),
        .dfp_rdata(dcache_dfp_rdata),
        .dfp_wdata(dcache_dfp_wdata),
        .dfp_resp (dcache_dfp_resp )
    );

    n_cacheline_adapter cacheline_adapter_i (
        .clk,
        .rst(rst),
        .bmem_addr,
        .bmem_read,
        .bmem_write,
        .bmem_wdata,
        .bmem_ready,
        .bmem_raddr,
        .bmem_rdata,
        .bmem_rvalid,
        .dcache_addr(dcache_dfp_addr),
        .dcache_read(dcache_dfp_read),
        .dcache_write(dcache_dfp_write),
        .dcache_rdata(dcache_dfp_rdata),
        .dcache_wdata(dcache_dfp_wdata),
        .dcache_resp(dcache_dfp_resp),
        .icache_addr(icache_dfp_addr),
        .icache_read(icache_dfp_read),
        .icache_write(icache_dfp_write),
        .icache_rdata(icache_dfp_rdata),
        .icache_wdata(icache_dfp_wdata),
        .icache_resp(icache_dfp_resp)
    );
    
    load_store_queue #(
        .DEPTH_BITS(LSQSIZE_BITS), 
        .NSIZE(NSIZE)
    ) load_store_queue_i (
        .clk,
        .rst             (rst | rob_flush),
        .din             (lsq_din             ),
        .enqueue         (lsq_enqueue         ),
        .dequeue         (lsq_dequeue         ),
        .bus             (lsq_bus             ),
        .dout            (lsq_dout            ),
        .lsq_id_to_insert(lsq_lsq_id_to_insert),
        .freespace       (lsq_freespace       ),
        .elemcount       (lsq_elemcount       )
    );
    
    //store_buffer #(
    //    .ROB_DEPTH_BITS(ROBSIZE_BITS), 
    //    .LSQ_DEPTH_BITS(LSQSIZE_BITS), 
    //    .NSIZE(NSIZE),
    //    .DEPTH(8)
    load_store_logic #(
         .ROB_DEPTH_BITS(ROBSIZE_BITS), 
         .DEPTH_BITS(LSQSIZE_BITS), 
         .NSIZE(NSIZE)
    ) load_store_logic_i (
        .rst,
        .clk,
        .rob_flush,
        
        .lsq_dequeue,
        .lsq_dout,
        .lsq_elemcount,
        
        .data_ufp_addr (dcache_ufp_addr ),
        .data_ufp_rmask(dcache_ufp_rmask),
        .data_ufp_wmask(dcache_ufp_wmask),
        .data_ufp_rdata(dcache_ufp_rdata),
        .data_ufp_wdata(dcache_ufp_wdata),
        .data_ufp_resp (dcache_ufp_resp ),
        
        .cdb_busy(ls_logic_cdb_busy),
        .cdb(global_cdb[COMPUTE_BASE_COUNT + COMPUTE_MUL_COUNT + COMPUTE_DIV_COUNT + COMPUTE_BRANCH_COUNT]),
        
        .rob_elemcount,
        .rob_current_tail_addr,
        
        .store_done(ls_logic_store_done),
        .store_monitor_mem_wdata(ls_logic_store_monitor_mem_wdata),
        .store_monitor_mem_wmask(ls_logic_store_monitor_mem_wmask),
        .store_monitor_mem_addr(ls_logic_store_monitor_mem_addr),
        .store_monitor_rs1_rdata(ls_logic_store_monitor_rs1_rdata),
        .store_monitor_rs2_rdata(ls_logic_store_monitor_rs2_rdata)
    );

    branch_queue #(
        .DEPTH_BITS(BQSIZE_BITS), 
        .NSIZE(NSIZE)
    ) branch_queue_i (
        .clk,
        .rst             (rst | rob_flush),
        .din             (bq_din             ),
        .enqueue         (bq_enqueue         ),
        .dequeue         (bq_dequeue         ),
        .bus             (bq_bus             ),
        .dout            (bq_dout            ),
        .bq_id_to_insert (bq_bq_id_to_insert),
        .freespace       (bq_freespace       ),
        .elemcount       (bq_elemcount       )
    );
    
    n_reservation_station #(
        .PR_BITS(PR_BITS), 
        .DEPTH_BITS(RSSIZE_BITS), 
        .NSIZE(NSIZE), 
        .CDB_COUNT(CDB_COUNT), 
        .BASE_COUNT(COMPUTE_BASE_COUNT), 
        .MUL_COUNT(COMPUTE_MUL_COUNT), 
        .DIV_COUNT(COMPUTE_DIV_COUNT), 
        .BRANCH_COUNT(COMPUTE_BRANCH_COUNT), 
        .LS_COUNT(COMPUTE_LS_COUNT)
    ) reservation_station (
        .clk,
        .rst(rst | rob_flush),
        
        .cdb(global_cdb),
        
        .rs_freespace,
        .rs_enqueue,
        .rs_entry_din,
        
        .ps1_addr(regf_ps1_addr),
        .ps2_addr(regf_ps2_addr),
        
        .base_rs_entry_valid(base_alu_rs_entry_valid),
        .base_rs_entry_dout(base_alu_rs_entry_dout),
        
        .mul_rs_entry_valid(mul_alu_rs_entry_valid),
        .mul_rs_entry_dout(mul_alu_rs_entry_dout),
        .div_rs_entry_valid(div_alu_rs_entry_valid),
        .div_rs_entry_dout(div_alu_rs_entry_dout),
        
        .branch_rs_entry_valid(branch_alu_rs_entry_valid),
        .branch_rs_entry_dout(branch_alu_rs_entry_dout),
        
        .ls_rs_entry_valid(load_store_calculator_rs_entry_valid),
        .ls_rs_entry_dout(load_store_calculator_rs_entry_dout),
        
        .base_fn_ready(base_alu_ready),
        .mul_fn_ready(mul_alu_ready),
        .div_fn_ready(div_alu_ready),
        .branch_fn_ready(branch_alu_ready),
        .ls_fn_ready(load_store_calculator_ready)
    );
    
    genvar i;
    
    // base alus
    generate for(i = 0; i < COMPUTE_BASE_COUNT; i++) begin : generate_base_alus
        base_alu base_alu_inst (
            .clk,
            .rst(rst | rob_flush),
            // from reservation station
            .rs_entry_valid(base_alu_rs_entry_valid[i]),
            .rs_entry_dout(base_alu_rs_entry_dout[i]),
            // to reservation station
            .ready(base_alu_ready[i]),      // accepting reservation station requests (=1)
            // from regfile
            .ps1_data(regf_ps1_data[i]),
            .ps2_data(regf_ps2_data[i]),
            // to alu/cdb
            .cdb(global_cdb[i]),
            .stall(base_alu_stall)
        );
    end endgenerate

    // division alus
    generate for(i = 0; i < COMPUTE_MUL_COUNT; i++) begin : generate_mul_alus
        mul_alu mul_alu_inst (
            .clk,
            .rst(rst | rob_flush),
            // from reservation station
            .rs_entry_valid(mul_alu_rs_entry_valid[i]),
            .rs_entry_dout(mul_alu_rs_entry_dout[i]),
            // to reservation station
            .ready(mul_alu_ready[i]),
            // from regfile
            .ps1_data(regf_ps1_data[COMPUTE_BASE_COUNT + i]),
            .ps2_data(regf_ps2_data[COMPUTE_BASE_COUNT + i]),
            // to alu/cdb
            .cdb(global_cdb[COMPUTE_BASE_COUNT + i]),
            .stall(mul_stall)
        );
    end endgenerate

    // division alus
    generate for(i = 0; i < COMPUTE_DIV_COUNT; i++) begin : generate_div_alus
        div_alu div_alu_inst (
            .clk,
            .rst(rst | rob_flush),
            // from reservation station
            .rs_entry_valid(div_alu_rs_entry_valid[i]),
            .rs_entry_dout(div_alu_rs_entry_dout[i]),
            // to reservation station
            .ready(div_alu_ready[i]),
            // from regfile
            .ps1_data(regf_ps1_data[COMPUTE_BASE_COUNT + COMPUTE_MUL_COUNT + i]),
            .ps2_data(regf_ps2_data[COMPUTE_BASE_COUNT + COMPUTE_MUL_COUNT + i]),
            // to alu/cdb
            .cdb(global_cdb[COMPUTE_BASE_COUNT + COMPUTE_MUL_COUNT + i]),
            .stall(div_stall)
        );
    end endgenerate

    branch_alu branch_alu_inst (
        .clk, 
        .rst(rst | rob_flush), 
        .rs_entry_valid (branch_alu_rs_entry_valid[0]),
        .rs_entry_dout  (branch_alu_rs_entry_dout[0]),
        .ready          (branch_alu_ready[0]),
        .ps1_data       (regf_ps1_data[COMPUTE_BASE_COUNT + COMPUTE_MUL_COUNT + COMPUTE_DIV_COUNT]),
        .ps2_data       (regf_ps2_data[COMPUTE_BASE_COUNT + COMPUTE_MUL_COUNT + COMPUTE_DIV_COUNT]),
        .bq_bus,
        .cdb            (global_cdb[COMPUTE_BASE_COUNT + COMPUTE_MUL_COUNT + COMPUTE_DIV_COUNT]),
        .stall          (branch_stall)
    );
    
    load_store_calculator load_store_calculator_inst (
        .clk,
        .rst(rst | rob_flush),
        // from reservation station
        .rs_entry_valid(load_store_calculator_rs_entry_valid[0]),
        .rs_entry_dout(load_store_calculator_rs_entry_dout[0]),
        // to reservation station
        .ready(load_store_calculator_ready[0]),
        // from regfile
        .ps1_data(regf_ps1_data[COMPUTE_BASE_COUNT + COMPUTE_MUL_COUNT + COMPUTE_DIV_COUNT + COMPUTE_BRANCH_COUNT]),
        .ps2_data(regf_ps2_data[COMPUTE_BASE_COUNT + COMPUTE_MUL_COUNT + COMPUTE_DIV_COUNT + COMPUTE_BRANCH_COUNT]),
        // to load store queue
        .lsq_bus
    );
    
    // what is this section for?
    always_comb begin
        branch_stall = 1'b0;
        mul_stall = 1'b0;
        div_stall = 1'b0;
        base_alu_stall = 1'b0;
        ls_logic_cdb_busy = 1'b0;
    end
    
endmodule : cpu
