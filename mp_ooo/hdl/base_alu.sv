module base_alu 
import rv32i_types::*;
(
    input   logic                       clk,
    input   logic                       rst,        // active high
    // from reservation station
    input   logic                       rs_entry_valid,
    input   rs_entry_t                  rs_entry_dout,
    // to reservation station
    output  logic                       ready,      // accepting reservation station requests (=1)
    // from regfile
    input   logic   [31:0]              ps1_data,
    input   logic   [31:0]              ps2_data,
    // to alu/cdb
    output  cdb_t                       cdb,
    input   logic                       stall
);
            // pipeline stage register for execution
            logic   [31:0]              ps1_data_reg;
            logic   [31:0]              ps2_data_reg;
            rs_entry_t                  rs_entry_reg;
            logic                       valid_reg;
            
            // logic                       executing; // flag
            // from mp_verif
            logic   [31:0]  a;
            logic   [31:0]  b;

            logic   [2:0]   aluop;
            logic   [2:0]   cmpop;

            logic   [31:0]  aluout;
            logic           br_en;

    logic signed   [31:0] as;
    logic signed   [31:0] bs;
    logic unsigned [31:0] au;
    logic unsigned [31:0] bu;

    assign as =   signed'(a);
    assign bs =   signed'(b);
    assign au = unsigned'(a);
    assign bu = unsigned'(b);

    always_comb begin
        unique case (aluop)
            alu_op_add: aluout = au +   bu;
            alu_op_sll: aluout = au <<  bu[4:0]; // shifts up to 32 bits
            alu_op_sra: aluout = unsigned'(as >>> bu[4:0]); // shifts up to 32 bits
            alu_op_sub: aluout = au -   bu;
            alu_op_xor: aluout = au ^   bu;
            alu_op_srl: aluout = au >>  bu[4:0]; // shifts up to 32 bits
            alu_op_or : aluout = au |   bu;
            alu_op_and: aluout = au &   bu;
            default   : aluout = 'x;
        endcase
    end

    always_comb begin
        unique case (cmpop)
            branch_f3_beq : br_en = (au == bu);
            branch_f3_bne : br_en = (au != bu);
            branch_f3_blt : br_en = (as <  bs);
            branch_f3_bge : br_en = (as >= bs); // branch if greater than or equal to
            branch_f3_bltu: br_en = (au <  bu);
            branch_f3_bgeu: br_en = (au >= bu); // branch if greater than or equal to
            default       : br_en = 1'bx;
        endcase
    end


    assign ready = 1'b1 & ~stall; // should always be ready unless stalled


    // assign stage reg
    always_ff @ (posedge clk) begin
        if (rst) begin
            valid_reg <= 1'b0;
        end else if (ready) begin
            valid_reg <= rs_entry_valid;
        end
        if (ready) begin
            ps1_data_reg <= ps1_data;
            ps2_data_reg <= ps2_data;
            rs_entry_reg <= rs_entry_dout;
        end
    end

    always_comb begin
        // from mp_verif
        a = 'x;
        b = 'x;
        aluop      = 'x;
        cmpop      = 'x;

        cdb.ready = valid_reg;
        cdb.rob_id = rs_entry_reg.rob_id;
        cdb.ar_dest = rs_entry_reg.rd_addr;
        cdb.pr_dest = rs_entry_reg.pd_addr;
        cdb.result  = 'x; // determined by opcode
        cdb.monitor_rs1_rdata = ps1_data_reg;
        cdb.monitor_rs2_rdata = ps2_data_reg;
        cdb.monitor_mem_rmask = '0;
        cdb.monitor_mem_rdata = 'x;
        cdb.monitor_mem_addr  = 'x;

        unique case(rs_entry_reg.opcode)
            op_b_lui: begin
                cdb.result  = rs_entry_reg.imm;
            end
            op_b_imm: begin
                a = ps1_data_reg;
                b = rs_entry_reg.imm;
                unique case (rs_entry_reg.funct3)
                    arith_f3_slt: begin
                        cmpop = branch_f3_blt;
                        cdb.result = {31'd0, br_en};
                    end
                    arith_f3_sltu: begin
                        cmpop = branch_f3_bltu;
                        cdb.result = {31'd0, br_en};
                    end
                    arith_f3_sr: begin
                        if (rs_entry_reg.funct7[5]) begin
                            aluop = alu_op_sra;
                        end else begin
                            aluop = alu_op_srl;
                        end
                        cdb.result = aluout;
                    end
                    default: begin
                        aluop = rs_entry_reg.funct3;
                        cdb.result = aluout;
                    end
                endcase
            end
            op_b_reg: begin
                a = ps1_data_reg;
                b = ps2_data_reg;
                unique case (rs_entry_reg.funct3)
                    arith_f3_slt: begin
                        cmpop = branch_f3_blt;
                        cdb.result = {31'd0, br_en};
                    end
                    arith_f3_sltu: begin
                        cmpop = branch_f3_bltu;
                        cdb.result = {31'd0, br_en};
                    end
                    arith_f3_sr: begin
                        if (rs_entry_reg.funct7[5]) begin
                            aluop = alu_op_sra;
                        end else begin
                            aluop = alu_op_srl;
                        end
                        cdb.result = aluout;
                    end
                    arith_f3_add: begin
                        if (rs_entry_reg.funct7[5]) begin
                            aluop = alu_op_sub;
                        end else begin
                            aluop = alu_op_add;
                        end
                        cdb.result = aluout;
                    end
                    default: begin
                        aluop = rs_entry_reg.funct3;
                        cdb.result = aluout;
                    end
                endcase
            end
            op_b_auipc: begin
                a = rs_entry_reg.PC;
                b = rs_entry_reg.imm;
                aluop = arith_f3_add;
                cdb.result = aluout;
            end
            default: begin
            end
        endcase

    end

endmodule
