/* 
    Note: seperate PC module, update iff branch mispredict or imem resp
*/
module PC
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,
    input   logic           move_pc,
    input   logic   [3:0]   move_amount,
    input   logic   [31:0]  Br_PC,
    input   logic   [63:0]  Br_order,
    input   logic           Br_valid,
    output  logic   [31:0]  PC,
    output  logic   [31:0]  PC_next,
    output  logic   [63:0]  order
);

    always_comb begin
        if (Br_valid)
            PC_next = Br_PC;
        else
            PC_next = PC + (32'(move_amount) * 32'd4);
    end

    always_ff @ (posedge clk) begin
        if(rst) begin
            PC <= rst_addr;
            order <= '0;
        end else if (Br_valid) begin
            /* Wrong branch predict: goto branch target */
            PC <= PC_next;
            order <= Br_order + 64'd1;
        end else if(move_pc) begin
            /* Naive branch predict: always not taken */
            PC <= PC_next;
            order <= order + 64'(move_amount);
        end
    end
endmodule
