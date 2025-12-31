module cpu
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,

    output  logic   [31:0]  imem_addr,
    output  logic   [3:0]   imem_rmask,
    input   logic   [31:0]  imem_rdata,
    input   logic           imem_resp,

    output  logic   [31:0]  dmem_addr,
    output  logic   [3:0]   dmem_rmask,
    output  logic   [3:0]   dmem_wmask,
    input   logic   [31:0]  dmem_rdata,
    output  logic   [31:0]  dmem_wdata,
    input   logic           dmem_resp
);
            // stall signals
            logic           stall_FE, stall_DE, stall_EX, stall_MEM;
            // valid signals
            logic           valid_FE, valid_DE, valid_EX, valid_MEM, valid_WB;
            // PC register
            logic   [31:0]  pc;
            logic   [31:0]  pc_next;
            
            // regfile signals
            // reading from regfile
            logic   [4:0]   rs1_s, rs2_s;
            logic   [31:0]  rs1_v, rs2_v;

            // writing to regfile
            logic           regf_we;
            logic   [4:0]   rd_s;
            logic   [31:0]  rd_v;

            // forwarding stuff
            logic   [31:0]  rs1_data_ex, rs2_data_ex;
            logic   [4:0]   rs1_addr_ex, rs2_addr_ex;
            logic   [31:0]  rd_data_mem_load; // rd data from load instruction
            logic           stall_load_rd; // flag from forwarding module to determine stall mem

            // saved instruction in fetch if fetch is stalled somehow
            logic           saved_fetch;
            logic           saved_load_rd;

            

            // branches
            logic           br_en;
            logic   [31:0]  br_pc_next;
            logic   [63:0]  br_order;

            // stage registers
            fe_de_stage_reg_t DE_stage_reg;
            de_ex_stage_reg_t EX_stage_reg;
            ex_mem_stage_reg_t MEM_stage_reg;
            mem_wb_stage_reg_t WB_stage_reg;

            // RVFI signals
            logic   [63:0]  order;
            rvfi_t  DE_rvfi_monitor, EX_rvfi_monitor, MEM_rvfi_monitor, WB_rvfi_monitor;


    // assign stall signals
    assign stall_FE  = stall_DE | (~imem_resp & ~saved_fetch);
    assign stall_DE  = stall_EX; // stall when execute stage is stalled 
    assign stall_EX  = stall_MEM; // stall when memory stage is stalled
    assign stall_MEM = (MEM_stage_reg.dmem_instr & ~dmem_resp & ~saved_load_rd)
                        | stall_load_rd; // load/store instruction and no dmem response yet
    // assign stall_WB  = stall_MEM;

    // assign valid signals // TODO will involve branch/jumps
    assign valid_FE  = ~rst & ~stall_FE & ~br_en; // valid only when ready proceed // TODO will involve branches. will latch later
    assign valid_DE  = ~rst & ~br_en & ~stall_DE;
    assign valid_EX  = ~rst;
    assign valid_MEM = ~rst;
    assign valid_WB  = ~rst;

    assign pc_next = br_en ? br_pc_next : pc + 32'd4; // TODO will involve branch/jumps

    // update PC
    always_ff @(posedge clk) begin
        if (rst) begin
            pc    <= 32'h1eceb000;
            order <= '0;
        end else if (~stall_FE) begin // fetch stage will only be ready when not stalled
            if (br_en) begin
                order <= br_order + 64'd1;
            end else begin
                order <= order + 64'd1;
            end
            pc    <= pc_next;
        end
    end

    

    regfile regfile(
        .*
    );


    forward forward(
        // inputs
        .clk(clk),
        .rst(rst),
        // requested by EX
        .rs1_addr_ex(rs1_addr_ex),
        .rs2_addr_ex(rs2_addr_ex),

        // data from regfile
        .rs1_data_regfile(rs1_v),
        .rs2_data_regfile(rs2_v),

        // rd to check and data to forward
        .rd_addr_mem(MEM_stage_reg.rd_addr),
        .rd_data_mem(MEM_stage_reg.rd_data),
        .rd_addr_wb(WB_stage_reg.rd_addr),
        .rd_data_wb(WB_stage_reg.rd_data),
        // load exception!
        .load_instr(MEM_stage_reg.load_instr),
        .dmem_resp(dmem_resp),
        .update_saved(~stall_EX & EX_stage_reg.valid),
        .update_WB(~stall_MEM & MEM_stage_reg.valid),
        .stall_EX(stall_EX),
        // .rd_data_mem_load(rd_data_mem_load), // rd data from dmem
        
        // outputs
        .saved(saved_load_rd),
        // tell MEM to stall
        .stall_load_rd(stall_load_rd),
        // data to forward to EX
        .rs1_data_ex(rs1_data_ex),
        .rs2_data_ex(rs2_data_ex)
    );

    fetch FE_stage(
        .stall(stall_FE),
        .valid(valid_FE),
        .saved(saved_fetch),
        .*
    );

    decode DE_stage(
        .stall(stall_DE),
        .valid(valid_DE),
        .*
    );

    execute EX_stage(
        .stall(stall_EX),
        .valid(valid_EX),
        .rs1_data(rs1_data_ex),
        .rs2_data(rs2_data_ex),
        .rs1_addr(rs1_addr_ex),
        .rs2_addr(rs2_addr_ex),
        .pc_next(br_pc_next),
        .order(br_order),
        .*
    );
    
    memory MEM_stage(
        .stall(stall_MEM),
        .valid(valid_MEM),
        .rd_data_load(rd_data_mem_load),
        // .regfile_rd_data(rd_v),
        // .regfile_rd_addr(rd_s),
        // .regfile_we(regf_we),
        .*
    );
    
    writeback WB_stage(
        // .stall(stall_WB),
        // .valid(valid_WB),
        .*
    );

endmodule : cpu
