module execute
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,

    input   logic           stall,
    input   logic           valid,
    // input   logic           stall_MEM,

    // register data and addrs
    input   logic   [31:0]  rs1_data, rs2_data,
    output  logic   [4:0]   rs1_addr, rs2_addr,

    // data memory requests
    output  logic   [31:0]  dmem_addr,
    output  logic   [3:0]   dmem_rmask,
    output  logic   [3:0]   dmem_wmask,
    output  logic   [31:0]  dmem_wdata,
    input   logic           dmem_resp,
    // load instructions who receive resp early and need to save rd data into MEM stage reg
    input   logic   [31:0]  rd_data_mem_load,

    // branches
    output  logic           br_en,
    output  logic   [31:0]  pc_next,
    output  logic   [63:0]  order,
    input   logic           stall_FE, // when fetch is stall, we need to save pc_next!

    // stage registers
    input   de_ex_stage_reg_t EX_stage_reg,
    output  ex_mem_stage_reg_t MEM_stage_reg,

    // RVFI monitors
    input   rvfi_t          EX_rvfi_monitor,
    output  rvfi_t          MEM_rvfi_monitor
);
            // convenient aliases
            logic   [31:0]  pc;
            instr_t         inst;
            logic   [2:0]   funct3;
            logic   [6:0]   funct7;
            logic   [6:0]   opcode;
            logic   [31:0]  i_imm;
            logic   [31:0]  s_imm;
            logic   [31:0]  b_imm;
            logic   [31:0]  u_imm;
            logic   [31:0]  j_imm;

            // inputs to ALU and CMP
            logic   [31:0]  a;
            logic   [31:0]  b;

            logic   [2:0]   aluop;
            logic   [2:0]   cmpop;
            // outputs of ALU and CMP
            logic   [31:0]  aluout;
            logic           cmpout;
            // logic           br_en;

            // writing to regfile
            logic           regf_we;
            logic   [4:0]   rd_s;
            logic   [31:0]  rd_v;

            // determine next valid
            logic           next_valid;
            // determine next load addr
            logic   [31:0]  next_load_addr;
            // save pc next for later
            logic           saved;
            logic   [31:0]  saved_pc_next;
            logic   [63:0]  saved_order;
            
            // rvfi requirements
            // logic   [4:0]   rs1_s, rs2_s;
            // logic   [4:0]   rvfi_rs1_addr;
            // logic   [4:0]   rvfi_rs2_addr;
            logic   [31:0]  rvfi_rs1_data;
            logic   [31:0]  rvfi_rs2_data;

            
        
    assign next_valid = EX_stage_reg.valid;

    assign pc = EX_stage_reg.pc;
    assign inst = EX_stage_reg.instr;
    assign funct3 = inst[14:12];
    assign funct7 = inst[31:25];
    assign opcode = inst[6:0];
    // immediate values, see page 12 of https://riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf
    assign i_imm  = {{21{inst[31]}}, inst[30:20]};
    assign s_imm  = {{21{inst[31]}}, inst[30:25], inst[11:7]};
    assign b_imm  = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
    assign u_imm  = {inst[31:12], 12'h000};
    assign j_imm  = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
    // assign rd_s   = inst[11:7];
    
    // alias
    assign aluop = EX_stage_reg.aluop;
    assign cmpop = EX_stage_reg.cmpop;
    // assign rs1_s = EX_stage_reg.rs1_addr;
    // assign rs2_s = EX_stage_reg.rs2_addr;
    assign rs1_addr = EX_stage_reg.rs1_addr;
    assign rs2_addr = EX_stage_reg.rs2_addr;


    // signed and unsigned a and b
    logic signed   [31:0] as;
    logic signed   [31:0] bs;
    logic unsigned [31:0] au;
    logic unsigned [31:0] bu;

    assign as =   signed'(a);
    assign bs =   signed'(b);
    assign au = unsigned'(a);
    assign bu = unsigned'(b);

    // ALU
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

    // CMP
    always_comb begin
        unique case (cmpop)
            branch_f3_beq : cmpout = (au == bu);
            branch_f3_bne : cmpout = (au != bu);
            branch_f3_blt : cmpout = (as <  bs);
            branch_f3_bge : cmpout = (as >= bs); // branch if greater than or equal to
            branch_f3_bltu: cmpout = (au <  bu);
            branch_f3_bgeu: cmpout = (au >= bu); // branch if greater than or equal to
            default       : cmpout = 1'b0; // zero when not taken
        endcase
    end


    always_ff @(posedge clk) begin
        if (rst) begin
            saved         <= 1'b0;
            saved_pc_next <= 'x;
            saved_order   <= 'x;
        end else if (stall_FE & br_en & ~saved & next_valid) begin
            saved         <= 1'b1;
            saved_pc_next <= pc_next;
            saved_order   <= EX_rvfi_monitor.order;
        end else if (~stall_FE) begin
            saved         <= 1'b0;
            saved_pc_next <= 'x;
            saved_order   <= 'x;
        end
    end

    

    always_comb begin
        pc_next     = pc + 32'd4;
        order       = saved ? saved_order : EX_rvfi_monitor.order;
        br_en       = 1'b0;

        dmem_addr   = 'x;
        dmem_rmask  = '0;
        dmem_wmask  = '0;
        dmem_wdata  = 'x;

        // rs1_addr = '0;
        // rs2_addr = '0;

        regf_we    = 1'b0;
        rd_s       = '0; // set only for instructions that use rd
        rd_v       = 'x;
        
        a          = 'x;
        b          = 'x;
        // aluop      = 'x;
        // cmpop      = 'x;

        next_load_addr = 'x;
        // rvfi_rs1_addr = '0;
        // rvfi_rs2_addr = '0;
        rvfi_rs1_data = '0;
        rvfi_rs2_data = '0;

        unique case (opcode)
            op_b_lui: begin
                regf_we = next_valid;
                rd_s = inst[11:7];
                rd_v = u_imm;
                
                // pc_next = pc + 'd4;
            end
            op_b_auipc: begin
                regf_we = next_valid;
                rd_s = inst[11:7];
                rd_v = pc + u_imm;

                // pc_next = pc + 'd4;
            end
            op_b_jal: begin // TODO
                regf_we = next_valid;
                rd_s = inst[11:7];
                rd_v = pc + 'd4;

                pc_next = pc + j_imm;
                br_en = 1'b1;
            end
            op_b_jalr: begin // TODO
                regf_we = next_valid;
                rd_s = inst[11:7];
                rd_v = pc + 'd4;

                pc_next = (rs1_data + i_imm) & 32'hfffffffe;
                br_en = 1'b1;
                // rs1_addr = rs1_s;
                // rvfi_rs1_addr = rs1_s;
                rvfi_rs1_data = rs1_data;
            end
            op_b_br: begin // TODO
                // cmpop = funct3;
                a = rs1_data;
                b = rs2_data;
                if (cmpout) begin
                    pc_next = pc + b_imm;
                end
                br_en = cmpout;

                // else begin
                //     pc_next = pc + 'd4;
                // end
                // rs1_addr = rs1_s;
                // rs2_addr = rs2_s;

                rvfi_rs1_data = rs1_data;
                rvfi_rs2_data = rs2_data;
                // rvfi_rs1_addr = rs1_s;
                // rvfi_rs2_addr = rs2_s;
            end
            op_b_load: begin
                dmem_addr = i_imm + rs1_data; // byte address = rs1 + imm11
                next_load_addr = dmem_addr;
                unique case (funct3)
                    load_f3_lb, load_f3_lbu: dmem_rmask = (4'b0001) << dmem_addr[1:0];
                    load_f3_lh, load_f3_lhu: dmem_rmask = (4'b0011) << dmem_addr[1:0];
                    load_f3_lw             : dmem_rmask = (4'b1111);
                    default                : dmem_rmask = '0;
                endcase
                dmem_rmask = dmem_rmask & {4{~stall & next_valid}};
                dmem_addr[1:0] = 2'd0;
                rd_s = inst[11:7];
                // rs1_addr = rs1_s;

                rvfi_rs1_data = rs1_data;
                // rvfi_rs1_addr = rs1_s;
            end
            op_b_store: begin
                dmem_addr = rs1_data + s_imm;
                next_load_addr = dmem_addr;
                unique case (funct3)
                    store_f3_sb: dmem_wmask = (4'b0001) << dmem_addr[1:0];
                    store_f3_sh: dmem_wmask = (4'b0011) << dmem_addr[1:0];
                    store_f3_sw: dmem_wmask = (4'b1111);
                    default    : dmem_wmask = '0;
                endcase
                unique case (funct3)
                    store_f3_sb: dmem_wdata[8 *dmem_addr[1:0] +: 8 ] = rs2_data[7 :0];
                    store_f3_sh: dmem_wdata[16*dmem_addr[1]   +: 16] = rs2_data[15:0];
                    store_f3_sw: dmem_wdata = rs2_data;
                    default    : dmem_wdata = 'x;
                endcase
                dmem_wmask = dmem_wmask & {4{~stall & next_valid}};
                // if (mem_resp) begin
                //     pc_next = pc + 'd4;
                // end
                dmem_addr[1:0] = 2'd0;
                // rs1_addr = rs1_s;
                // rs2_addr = rs2_s;
                
                rvfi_rs1_data = rs1_data;
                rvfi_rs2_data = rs2_data;
                // rvfi_rs1_addr = rs1_s;
                // rvfi_rs2_addr = rs2_s;
            end
            op_b_imm: begin
                a = rs1_data;
                b = i_imm;
                rd_s = inst[11:7];
                unique case (funct3)
                    arith_f3_slt: begin
                        // cmpop = branch_f3_blt;
                        rd_v = {31'd0, cmpout};
                    end
                    arith_f3_sltu: begin
                        // cmpop = branch_f3_bltu;
                        rd_v = {31'd0, cmpout};
                    end
                    arith_f3_sr: begin
                        // if (funct7[5]) begin
                        //     aluop = alu_op_sra;
                        // end else begin
                        //     aluop = alu_op_srl;
                        // end
                        rd_v = aluout;
                    end
                    default: begin
                        // aluop = funct3;
                        rd_v = aluout;
                    end
                endcase
                regf_we = next_valid;
                // pc_next = pc + 'd4;
                // rs1_addr = rs1_s;

                rvfi_rs1_data = rs1_data;
                // rvfi_rs1_addr = rs1_s;
            end
            op_b_reg: begin
                a = rs1_data;
                b = rs2_data;
                rd_s = inst[11:7];
                unique case (funct3)
                    arith_f3_slt: begin
                        // cmpop = branch_f3_blt;
                        rd_v = {31'd0, cmpout};
                    end
                    arith_f3_sltu: begin
                        // cmpop = branch_f3_bltu;
                        rd_v = {31'd0, cmpout};
                    end
                    arith_f3_sr: begin
                        // if (funct7[5]) begin
                        //     aluop = alu_op_sra;
                        // end else begin
                        //     aluop = alu_op_srl;
                        // end
                        rd_v = aluout;
                    end
                    arith_f3_add: begin
                        // if (funct7[5]) begin
                        //     aluop = alu_op_sub;
                        // end else begin
                        //     aluop = alu_op_add;
                        // end
                        rd_v = aluout;
                    end
                    default: begin
                        // aluop = funct3;
                        rd_v = aluout;
                    end
                endcase
                regf_we = next_valid;
                // rs1_addr = rs1_s;
                // rs2_addr = rs2_s;

                // pc_next = pc + 'd4;
                rvfi_rs1_data = rs1_data;
                rvfi_rs2_data = rs2_data;
                // rvfi_rs1_addr = rs1_s;
                // rvfi_rs2_addr = rs2_s;
            end
            default: begin // do nothing

            end
        endcase
        pc_next = saved ? saved_pc_next : pc_next;
        br_en   = (br_en & EX_stage_reg.valid) | saved;

    end

    // updating memory stage register
    always_ff @(posedge clk) begin
        if (rst) begin
            MEM_stage_reg.instr       <= 'x;
            MEM_stage_reg.pc          <= 'x;
            MEM_stage_reg.load_addr   <= 'x;
            MEM_stage_reg.valid       <= 1'b0;
            MEM_stage_reg.dmem_instr  <= 1'b0;
            MEM_stage_reg.load_instr  <= 1'b0;
            MEM_stage_reg.regfile_we  <= 1'b0;
        end else if (~stall) begin
            MEM_stage_reg.instr       <= inst;
            MEM_stage_reg.pc          <= pc;
            MEM_stage_reg.load_addr   <= next_load_addr; // no zeroed out LSB 2
            MEM_stage_reg.valid       <= next_valid;
            MEM_stage_reg.dmem_instr  <= next_valid && (opcode == op_b_store || opcode == op_b_load);
            MEM_stage_reg.load_instr  <= next_valid && (opcode == op_b_load);
            MEM_stage_reg.regfile_we  <= regf_we & next_valid;
        end

        if (rst) begin
            MEM_stage_reg.rd_addr     <= 'x;
            MEM_stage_reg.rd_data     <= 'x;
        end else if (~stall & EX_stage_reg.valid) begin
            MEM_stage_reg.rd_addr     <= rd_s;
            MEM_stage_reg.rd_data     <= rd_v;
        end else if (dmem_resp) begin // if received dmem response but MEM stage is not ready to continue
            MEM_stage_reg.rd_data     <= rd_data_mem_load;
        end
    end

    // updating rvfi monitor
    always_ff @(posedge clk) begin
        if (rst) begin
            MEM_rvfi_monitor.valid     <= 1'b0;
            MEM_rvfi_monitor.order     <= '0;
            MEM_rvfi_monitor.inst      <= 'x;
            MEM_rvfi_monitor.rs1_addr  <= 'x;
            MEM_rvfi_monitor.rs2_addr  <= 'x;
            MEM_rvfi_monitor.rs1_rdata <= 'x;
            MEM_rvfi_monitor.rs2_rdata <= 'x;
            MEM_rvfi_monitor.rd_addr   <= 'x;
            MEM_rvfi_monitor.rd_wdata  <= 'x;
            MEM_rvfi_monitor.pc_rdata  <= '0;
            MEM_rvfi_monitor.pc_wdata  <= 'x;
            MEM_rvfi_monitor.mem_addr  <= 'x;
            MEM_rvfi_monitor.mem_rmask <= 'x;
            MEM_rvfi_monitor.mem_wmask <= 'x;
            MEM_rvfi_monitor.mem_rdata <= 'x;
            MEM_rvfi_monitor.mem_wdata <= 'x;
        end else if (~stall) begin
            MEM_rvfi_monitor.valid     <= EX_rvfi_monitor.valid & valid;
            MEM_rvfi_monitor.order     <= EX_rvfi_monitor.order;
            MEM_rvfi_monitor.inst      <= EX_rvfi_monitor.inst;
            MEM_rvfi_monitor.rs1_addr  <= EX_rvfi_monitor.rs1_addr;
            MEM_rvfi_monitor.rs2_addr  <= EX_rvfi_monitor.rs2_addr;
            MEM_rvfi_monitor.rs1_rdata <= rvfi_rs1_data;
            MEM_rvfi_monitor.rs2_rdata <= rvfi_rs2_data;
            MEM_rvfi_monitor.rd_addr   <= rd_s; // determined in memory stage
            MEM_rvfi_monitor.rd_wdata  <= rd_v;
            MEM_rvfi_monitor.pc_rdata  <= EX_rvfi_monitor.pc_rdata;
            MEM_rvfi_monitor.pc_wdata  <= pc_next;
            MEM_rvfi_monitor.mem_addr  <= dmem_addr;
            MEM_rvfi_monitor.mem_rmask <= dmem_rmask;
            MEM_rvfi_monitor.mem_wmask <= dmem_wmask;
            MEM_rvfi_monitor.mem_rdata <= 'x;
            MEM_rvfi_monitor.mem_wdata <= dmem_wdata;
        end
    end

endmodule : execute