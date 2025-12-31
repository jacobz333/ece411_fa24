module decode
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,

    input   logic           stall,
    input   logic           valid,
    // input   logic           stall_EX,


    
    // request from regfile
    output  logic   [4:0]   rs1_s, rs2_s,

    input fe_de_stage_reg_t DE_stage_reg,
    output de_ex_stage_reg_t EX_stage_reg,
    // RVFI montiors
    input   rvfi_t          DE_rvfi_monitor,
    output  rvfi_t          EX_rvfi_monitor
);

            // aliases
            logic   [31:0]  pc;
            instr_t         instr;
            logic           next_valid; // valid to propagate
            logic   [2:0]   funct3;
            logic   [6:0]   funct7;
            logic   [6:0]   opcode;
            // to save into ex stage reg
            logic   [2:0]   aluop;
            logic   [2:0]   cmpop;
            // rvfi and for forwarding
            logic   [4:0]   rs1_addr;
            logic   [4:0]   rs2_addr;

    // assign alias
    assign pc = DE_stage_reg.pc;
    assign instr = DE_stage_reg.instr;
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];
    assign opcode = instr[6:0];
    // assign rs1, rs2. always read from regfile
    assign rs1_s = instr[19:15];
    assign rs2_s = instr[24:20];
    // determine next valid signal
    assign next_valid =  valid & DE_stage_reg.valid;

    always_comb begin
        rs1_addr = '0;
        rs2_addr = '0;

        aluop = 'x;
        cmpop = 'x;

        unique case (instr.i_type.opcode)
            op_b_lui: begin
            end
            op_b_auipc: begin
            end
            op_b_jal: begin
            end
            op_b_jalr: begin
                rs1_addr = rs1_s;
            end
            op_b_br: begin
                cmpop = funct3;
                rs1_addr = rs1_s;
                rs2_addr = rs2_s;
            end
            op_b_load: begin
                rs1_addr = rs1_s;
            end
            op_b_store: begin
                rs1_addr = rs1_s;
                rs2_addr = rs2_s;
            end
            op_b_imm: begin
                unique case (funct3)
                    arith_f3_slt: begin
                        cmpop = branch_f3_blt;
                    end
                    arith_f3_sltu: begin
                        cmpop = branch_f3_bltu;
                    end
                    arith_f3_sr: begin
                        if (funct7[5]) begin
                            aluop = alu_op_sra;
                        end else begin
                            aluop = alu_op_srl;
                        end
                    end
                    default: begin
                        aluop = funct3;
                    end
                endcase
                rs1_addr = rs1_s;
            end
            op_b_reg: begin
                unique case (funct3)
                    arith_f3_slt: begin
                        cmpop = branch_f3_blt;
                    end
                    arith_f3_sltu: begin
                        cmpop = branch_f3_bltu;
                    end
                    arith_f3_sr: begin
                        if (funct7[5]) begin
                            aluop = alu_op_sra;
                        end else begin
                            aluop = alu_op_srl;
                        end
                    end
                    arith_f3_add: begin
                        if (funct7[5]) begin
                            aluop = alu_op_sub;
                        end else begin
                            aluop = alu_op_add;
                        end
                    end
                    default: begin
                        aluop = funct3;
                    end
                endcase
                rs1_addr = rs1_s;
                rs2_addr = rs2_s;
            end
            default: begin // do nothing

            end
        endcase
    end

    // updating execute stage register
    always_ff @(posedge clk) begin
        if (rst) begin
            EX_stage_reg.instr <= 'x;
            EX_stage_reg.pc    <= 32'h1eceb000; // start here
            EX_stage_reg.valid <= 1'b0;
            EX_stage_reg.aluop <= 'x;
            EX_stage_reg.cmpop <= 'x;
            EX_stage_reg.rs1_addr <= 'x;
            EX_stage_reg.rs2_addr <= 'x;
        end else if (~stall) begin
            EX_stage_reg.instr <= instr;
            EX_stage_reg.pc    <= pc;
            EX_stage_reg.valid <= next_valid;
            EX_stage_reg.aluop <= aluop;
            EX_stage_reg.cmpop <= cmpop;
            EX_stage_reg.rs1_addr <= rs1_addr;
            EX_stage_reg.rs2_addr <= rs2_addr;
        end
    end

    // updating rvfi monitor
    always_ff @(posedge clk) begin
        if (rst) begin
            EX_rvfi_monitor.valid     <= 1'b0;
            EX_rvfi_monitor.order     <= '0;
            EX_rvfi_monitor.inst      <= 'x;
            EX_rvfi_monitor.rs1_addr  <= 'x;
            EX_rvfi_monitor.rs2_addr  <= 'x;
            EX_rvfi_monitor.rs1_rdata <= 'x;
            EX_rvfi_monitor.rs2_rdata <= 'x;
            EX_rvfi_monitor.rd_addr   <= 'x;
            EX_rvfi_monitor.rd_wdata  <= 'x;
            EX_rvfi_monitor.pc_rdata  <= '0;
            EX_rvfi_monitor.pc_wdata  <= 'x;
            EX_rvfi_monitor.mem_addr  <= 'x;
            EX_rvfi_monitor.mem_rmask <= 'x;
            EX_rvfi_monitor.mem_wmask <= 'x;
            EX_rvfi_monitor.mem_rdata <= 'x;
            EX_rvfi_monitor.mem_wdata <= 'x;
        end else if (~stall) begin
            EX_rvfi_monitor.valid     <= DE_rvfi_monitor.valid & valid;
            EX_rvfi_monitor.order     <= DE_rvfi_monitor.order;
            EX_rvfi_monitor.inst      <= DE_rvfi_monitor.inst;
            EX_rvfi_monitor.rs1_addr  <= rs1_addr;
            EX_rvfi_monitor.rs2_addr  <= rs2_addr;
            EX_rvfi_monitor.rs1_rdata <= 'x;
            EX_rvfi_monitor.rs2_rdata <= 'x;
            EX_rvfi_monitor.rd_addr   <= 'x;
            EX_rvfi_monitor.rd_wdata  <= 'x;
            EX_rvfi_monitor.pc_rdata  <= DE_rvfi_monitor.pc_rdata;
            EX_rvfi_monitor.pc_wdata  <= 'x;
            EX_rvfi_monitor.mem_addr  <= 'x;
            EX_rvfi_monitor.mem_rmask <= 'x;
            EX_rvfi_monitor.mem_wmask <= 'x;
            EX_rvfi_monitor.mem_rdata <= 'x;
            EX_rvfi_monitor.mem_wdata <= 'x;
        end
    end

endmodule : decode