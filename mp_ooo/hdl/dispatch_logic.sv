// Currently only supports N=1
module dispatch_logic
import rv32i_types::*;
#(
    parameter                   ROBSIZE_BITS = 4,
    parameter                   LSQSIZE_BITS = 4,
    parameter                   RSSIZE_BITS = 4,
    parameter                   BQSIZE_BITS = 4,
    parameter                   NSIZE_INSTRUCTIONS = 1,
    localparam                  NSIZE_INSTRUCTIONS_BITS = $clog2(NSIZE_INSTRUCTIONS),
    parameter                   NSIZE = 1,
    localparam                  NSIZE_BITS = $clog2(NSIZE),
    localparam     logic[3:0]   NSIZE_SMALL = NSIZE,
    parameter                   PR_BITS = 5,
    parameter                   FL_DEPTH_BITS = 5,
    parameter                   IQ_DEPTH_BITS = 3
) (
    output rob_entry_t                  rob_din[NSIZE],
    input  logic  [ROBSIZE_BITS:0]      rob_freespace,
    output logic  [NSIZE-1:0]           rob_enqueue,
    input  logic  [ROBSIZE_BITS-1:0]    rob_rob_id_to_insert[NSIZE],
    
    output lsq_entry_t                  lsq_din[NSIZE],
    input  logic  [LSQSIZE_BITS:0]      lsq_freespace,
    output logic  [NSIZE-1:0]           lsq_enqueue,
    input  logic  [LSQSIZE_BITS-1:0]    lsq_lsq_id_to_insert[NSIZE],

    output bq_entry_t                 bq_din[NSIZE],
    input  logic  [BQSIZE_BITS:0]     bq_freespace,
    output logic  [NSIZE-1:0]         bq_enqueue,
    input  logic  [BQSIZE_BITS-1:0]   bq_bq_id_to_insert[NSIZE],

    input  iq_entry_t                              iq_dout[NSIZE_INSTRUCTIONS],
    input  logic  [IQ_DEPTH_BITS:0]                iq_elemcount,
    output logic  [NSIZE_INSTRUCTIONS-1:0]         iq_dequeue,

    output logic  [4:0]               rat_alias_rd        [NSIZE],
    output logic  [PR_BITS-1:0]       rat_alias_pd        [NSIZE],
    output logic                      rat_alias_regf_we   [NSIZE],
    output logic  [4:0]               rat_alias_rs1       [NSIZE],
    input  logic  [PR_BITS-1:0]       rat_alias_ps1       [NSIZE],
    input  logic                      rat_alias_ps1_valid [NSIZE],
    output logic  [4:0]               rat_alias_rs2       [NSIZE],
    input  logic  [PR_BITS-1:0]       rat_alias_ps2       [NSIZE],
    input  logic                      rat_alias_ps2_valid [NSIZE],

    input  logic  [FL_DEPTH_BITS:0]   fl_elemcount,
    input  logic  [PR_BITS-1:0]       fl_dout[NSIZE],
    output logic  [NSIZE-1:0]         fl_dequeue,

    input  logic       [RSSIZE_BITS:0]   rs_freespace,
    output logic       [NSIZE-1:0]       rs_enqueue,
    output rs_entry_t                    rs_entry_din[NSIZE]
);
            // convenient alias
            instr_t instr;
            // immediate aliases
            logic   [31:0]  i_imm;
            logic   [31:0]  s_imm;
            logic   [31:0]  b_imm;
            logic   [31:0]  u_imm;
            logic   [31:0]  j_imm;
            // flag to indicate if the instruction is a mult_div
            logic           mult_div_flag;
            logic           load_store_flag;
            logic           branch_flag; // branch or jump
            logic           ignore_flag;
    
    logic [BQSIZE_BITS:0]   branches_added;
    logic [LSQSIZE_BITS:0]  ls_added;
    logic [FL_DEPTH_BITS:0] fl_removed;

    
    always_comb begin
        iq_dequeue = '0;
        rob_enqueue = '0;
        fl_dequeue = '0;
        rs_enqueue = '0;
        lsq_enqueue = '0;
        bq_enqueue = '0;
        
        ls_added = '0;
        branches_added = '0;
        fl_removed = '0;
        
        for(int unsigned i = 0; i < NSIZE; i++) begin
            rs_entry_din[i] = 'x;
            rob_din[i] = 'x;
            lsq_din[i] = 'x;
            bq_din[i] = 'x;
            rat_alias_regf_we[i] = '0;
            rat_alias_rd[i] = 'x;
            rat_alias_pd[i] = 'x;
            rat_alias_rs1[i] = 'x;
            rat_alias_rs2[i] = 'x;
        end
        
        for(int unsigned i = 0; i < NSIZE; i++) begin
            // pulled from mp_verif
            // immediate values, see page 12 of https://riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf
            
            instr = iq_dout[i].instruction;
            
            i_imm  = {{21{instr[31]}}, instr[30:20]};
            s_imm  = {{21{instr[31]}}, instr[30:25], instr[11:7]};
            b_imm  = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
            u_imm  = {instr[31:12], 12'h000};
            j_imm  = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
            
            
            mult_div_flag = (instr.r_type.opcode == op_b_reg && instr.r_type.funct7 == mult_div);
            load_store_flag = (instr.r_type.opcode == op_b_load || instr.r_type.opcode == op_b_store);
            branch_flag = (instr.b_type.opcode == op_b_br || instr.i_type.opcode == op_b_jalr || instr.j_type.opcode == op_b_jal);
            ignore_flag = iq_dout[i].instruction == '0 || iq_dout[i].instruction == 32'h100073 || iq_dout[i].instruction == 32'h73;
            
            rs_entry_din[i].rob_id = rob_rob_id_to_insert[i];
            rs_entry_din[i].lsq_id = lsq_lsq_id_to_insert[ls_added];
            rs_entry_din[i].bq_id = bq_bq_id_to_insert[branches_added];
            rs_entry_din[i].PC = iq_dout[i].pc;
            rs_entry_din[i].order = iq_dout[i].order;
            
            // assign immediate value from instruction
            unique case(instr.r_type.opcode)
                op_b_lui:   rs_entry_din[i].imm = u_imm;
                op_b_auipc: rs_entry_din[i].imm = u_imm;
                op_b_jal:   rs_entry_din[i].imm = j_imm;
                op_b_jalr:  rs_entry_din[i].imm = i_imm;
                op_b_br:    rs_entry_din[i].imm = b_imm;
                op_b_load:  rs_entry_din[i].imm = i_imm;
                op_b_store: rs_entry_din[i].imm = s_imm;
                op_b_imm:   rs_entry_din[i].imm = i_imm;
                op_b_reg:   rs_entry_din[i].imm = 'x;   // unused
                default:    rs_entry_din[i].imm = 'x;   // this should never happen
            endcase
            
            rob_din[i].monitor_regf_we = '0; // WE SHOULD CALCULATE THIS NOW 
            unique case(instr.r_type.opcode)
                op_b_lui, op_b_auipc, op_b_jal, op_b_jalr, op_b_imm, op_b_reg, op_b_load:
                    rob_din[i].monitor_regf_we = '1;
                default:
                    rob_din[i].monitor_regf_we = '0;
            endcase
            
            rat_alias_rd[i] = iq_dout[i].instruction[11:7]; // rd: [11-7]
            
            if(rob_din[i].monitor_regf_we == '0) begin // If we arent writing to a register in this instruction, the architectural destination register is set to 0
                rat_alias_rd[i] = '0;
            end
            
            if(rat_alias_rd[i] == '0) begin // If the architectural register is 0, or we arent writing into a register, then the physical destination register is 0
                rat_alias_pd[i] = '0;
            end else begin
                rat_alias_pd[i] = fl_dout[fl_removed];
            end
            rat_alias_rs1[i] = iq_dout[i].instruction[19:15]; // rs1: [19-15]
            rat_alias_rs2[i] = iq_dout[i].instruction[24:20]; // rs2: [24-20]
            
            // assign ps1,ps2 addr from instruction; zeroed if not needed for RVFI correctness
            unique case(instr.r_type.opcode)
                op_b_lui, op_b_auipc, op_b_jal: begin
                    rs_entry_din[i].ps1_addr    = '0; // unused
                    rs_entry_din[i].ps2_addr    = '0; // unused
                    rs_entry_din[i].ps1_valid   = 1'b1;
                    rs_entry_din[i].ps2_valid   = 1'b1;
                end
                op_b_jalr, op_b_load, op_b_imm: begin
                    rs_entry_din[i].ps1_addr    = rat_alias_ps1[i];
                    rs_entry_din[i].ps2_addr    = '0; // unused
                    rs_entry_din[i].ps1_valid   = rat_alias_ps1_valid[i];
                    rs_entry_din[i].ps2_valid   = 1'b1;
                end
                op_b_br, op_b_store, op_b_reg: begin
                    rs_entry_din[i].ps1_addr    = rat_alias_ps1[i];
                    rs_entry_din[i].ps2_addr    = rat_alias_ps2[i];
                    rs_entry_din[i].ps1_valid   = rat_alias_ps1_valid[i];
                    rs_entry_din[i].ps2_valid   = rat_alias_ps2_valid[i];
                end
                default: begin
                    rs_entry_din[i].ps1_addr    = 'x; // should never happen
                    rs_entry_din[i].ps2_addr    = 'x;
                    rs_entry_din[i].ps1_valid   = 'x;
                    rs_entry_din[i].ps2_valid   = 'x;
                end
            endcase
            rs_entry_din[i].rd_addr      = rat_alias_rd[i];
            rs_entry_din[i].pd_addr      = rat_alias_pd[i];
            rs_entry_din[i].opcode       = instr.r_type.opcode;
            rs_entry_din[i].funct3       = instr.r_type.funct3;
            rs_entry_din[i].funct7       = instr.r_type.funct7;
            
            
            // Currently unused variables, used later when adding reservation stations
            // if(rat_alias_ps2_valid[0] == '0 && rat_alias_ps2[0] == '0 && rat_alias_ps1_valid[0] == '0 && rat_alias_ps1[0] == '0) begin end
            
            
            
            rob_din[i].ready = '0;
            rob_din[i].pr_dest = rat_alias_pd[i];
            rob_din[i].monitor_order = iq_dout[i].order;
            rob_din[i].monitor_inst = iq_dout[i].instruction;
            // assign rs1,rs2 addr from instruction; zeroed if not needed for RVFI correctness
            unique case(instr.r_type.opcode)
                op_b_lui, op_b_auipc, op_b_jal: begin
                    rob_din[i].monitor_rs1_addr = '0;
                    rob_din[i].monitor_rs2_addr = '0;
                end
                op_b_jalr, op_b_load, op_b_imm: begin
                    rob_din[i].monitor_rs1_addr = rat_alias_rs1[i];
                    rob_din[i].monitor_rs2_addr = '0;
                end
                op_b_br, op_b_store, op_b_reg: begin
                    rob_din[i].monitor_rs1_addr = rat_alias_rs1[i];
                    rob_din[i].monitor_rs2_addr = rat_alias_rs2[i];
                end
                default: begin
                    rob_din[i].monitor_rs1_addr = 'x;
                    rob_din[i].monitor_rs2_addr = 'x;
                end
            endcase
            rob_din[i].monitor_rs1_rdata = 'x; // Get from CDB later
            rob_din[i].monitor_rs2_rdata = 'x; // Get from CDB later
            
            rob_din[i].monitor_rd_addr = rat_alias_rd[i];
            rob_din[i].monitor_rd_wdata = 'x; // Get from CDB later (result of calculation)
            rob_din[i].monitor_pc_rdata = iq_dout[i].pc;
            rob_din[i].monitor_pc_wdata = iq_dout[i].pc + 32'd4; // Replace with actual next PC value later
            rob_din[i].monitor_mem_addr = 'x; // Memory stage stuff
            rob_din[i].monitor_mem_rmask = '0; // Memory stage stuff
            rob_din[i].monitor_mem_wmask = '0; // Memory stage stuff
            rob_din[i].monitor_mem_rdata = 'x; // Memory stage stuff
            rob_din[i].monitor_mem_wdata = 'x; // Memory stage stuff
             
            lsq_din[ls_added].ready = '0;
            lsq_din[ls_added].rob_id = rob_rob_id_to_insert[i];
            lsq_din[ls_added].pr_dest = rat_alias_pd[i];
            lsq_din[ls_added].ar_dest = rat_alias_rd[i];
            lsq_din[ls_added].is_load = instr.r_type.opcode == op_b_load;
            lsq_din[ls_added].funct3  = instr.r_type.funct3;
            lsq_din[ls_added].mask    = 'x;
            lsq_din[ls_added].addr    = 'x;
            lsq_din[ls_added].wdata   = 'x;
            lsq_din[ls_added].monitor_rs1_rdata = 'x;
            lsq_din[ls_added].monitor_rs2_rdata = 'x;
            
            bq_din[branches_added].branch_taken = 'x;
            bq_din[branches_added].branch_target = 'x;
            bq_din[branches_added].branch_order  = iq_dout[i].order;
            
            
            if(ignore_flag && iq_elemcount > (IQ_DEPTH_BITS+1)'(i))
                iq_dequeue[i] = '1;
            
            if(!ignore_flag && fl_elemcount > fl_removed && rob_freespace > (ROBSIZE_BITS+1)'(i) && iq_elemcount > (IQ_DEPTH_BITS+1)'(i) && rs_freespace > (RSSIZE_BITS+1)'(i) && (!branch_flag || bq_freespace > branches_added) && (!load_store_flag || lsq_freespace > ls_added)) begin
                iq_dequeue[i] = '1;
                rob_enqueue[i] = '1;
                rs_enqueue[i] = '1;
                if (load_store_flag) begin
                    lsq_enqueue[ls_added] = '1;
                    ls_added = ls_added + (LSQSIZE_BITS+1)'(1);
                end else if (branch_flag) begin
                    bq_enqueue[branches_added] = '1;
                    branches_added = branches_added + (BQSIZE_BITS+1)'(1);
                end
                if(!(rat_alias_rd[i] == '0 || rob_din[i].monitor_regf_we == '0)) begin // Dont look into the freelist, or try to change the RAT, if the architectural register is 0 or we arent writing into a register
                    fl_dequeue[fl_removed] = '1;
                    rat_alias_regf_we[i] = '1;
                    fl_removed = fl_removed + (FL_DEPTH_BITS+1)'(1);
                end
            end else begin
                break;
            end
        end
    end
endmodule : dispatch_logic
