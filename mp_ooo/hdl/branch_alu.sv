/*
    Note: handles branch and jump
*/
module branch_alu
import rv32i_types::*;
(
    input   logic                       clk,
    input   logic                       rst,
    // from reservation station
    input   logic                       rs_entry_valid,
    input   rs_entry_t                  rs_entry_dout,
    // to reservation station
    output  logic                       ready, 
    // from regfile
    input   logic   [31:0]              ps1_data,
    input   logic   [31:0]              ps2_data,
    // to BQ
    output  bq_bus_t                    bq_bus,
    // to cdb
    output  cdb_t                       cdb,
    input   logic                       stall
);
/*
    Develop note: 
        1. branch: 
            1. compare rs1 rs2
            2. add pc imm
            3. enqueue BQ
        2. jal
            1. add pc 4 
            2. add pc imm
            3. save to pd and enqueue BQ
        3. jalr
            1. add pc 4
            2. add rs1 imm
            3. save to pd and enqueue BQ
        4. auipc
            1. add rs1 imm
            2. save to pd
*/
            logic   [31:0]              ps1_data_reg;
            logic   [31:0]              ps2_data_reg;
            rs_entry_t                  rs_entry_reg;
            logic                       valid_reg;

            logic   [31:0]  a;
            logic   [31:0]  b;

            logic   [2:0]   cmpop;
            logic   [6:0]   opcode;

            logic           br_en;

            logic   [31:0]  PC_target;

    logic signed   [31:0] as;
    logic signed   [31:0] bs;
    logic unsigned [31:0] au;
    logic unsigned [31:0] bu;

    assign as =   signed'(a);
    assign bs =   signed'(b);
    assign au = unsigned'(a);
    assign bu = unsigned'(b);

    assign ready = 1'b1 & ~stall;

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

    assign opcode = rs_entry_reg.opcode;

    always_comb begin
        // branch taken
        unique case (cmpop)
            branch_f3_beq : br_en = (au == bu);
            branch_f3_bne : br_en = (au != bu);
            branch_f3_blt : br_en = (as <  bs);
            branch_f3_bge : br_en = (as >= bs); 
            branch_f3_bltu: br_en = (au <  bu);
            branch_f3_bgeu: br_en = (au >= bu); 
            default       : br_en = 1'b1; // this is for jump - always taken
        endcase
    end

    always_comb begin
        a = 'x;
        b = 'x;
        cmpop = 'x;
        PC_target = 'x;

        cdb.ready = valid_reg;
        cdb.rob_id = rs_entry_reg.rob_id;
        cdb.ar_dest = rs_entry_reg.rd_addr;
        cdb.pr_dest = rs_entry_reg.pd_addr;
        cdb.result  = 'x; 
        cdb.monitor_rs1_rdata = ps1_data_reg;
        cdb.monitor_rs2_rdata = ps2_data_reg;
        cdb.monitor_mem_rmask = '0;
        cdb.monitor_mem_rdata = 'x;
        cdb.monitor_mem_addr  = 'x;

        // operation
        if (opcode == op_b_br) begin
            a = ps1_data_reg;
            b = ps2_data_reg;
            cmpop = rs_entry_reg.funct3;
            PC_target = rs_entry_reg.PC + rs_entry_reg.imm;
        end else if (opcode == op_b_jal) begin
            a = '0;
            b = '0;
            cmpop = '0;
            cdb.result = rs_entry_reg.PC + 32'd4;
            PC_target = (rs_entry_reg.PC + rs_entry_reg.imm) & 32'hfffffffe;
        end else if (opcode == op_b_jalr) begin
            a = '0;
            b = '0;
            cmpop = '0;
            cdb.result = rs_entry_reg.PC + 32'd4;
            PC_target = (ps1_data_reg + rs_entry_reg.imm) & 32'hfffffffe;
        end
    end

    always_comb begin
        bq_bus.ready = valid_reg;
        bq_bus.branch_taken = br_en;
        bq_bus.branch_target = PC_target;
        bq_bus.bq_id = rs_entry_reg.bq_id;
    end

endmodule
