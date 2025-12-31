/*
    Note: very simple branch predictor, may replace with advanced later
*/
module BranchPredictor #(
    parameter   BHT_DEPTH=32
)(
    input clk,
    input rst,
    input [31:0] PC_pred,
    input [31:0] PC_updt,
    input update,
    input taken,
    output reg prediction
);    
    // 2 bit BHT
    reg [1:0] BHT[BHT_DEPTH];

    // update BHT
    always @(posedge clk) begin
        if(rst) begin
            for(int i=0; i < BHT_DEPTH; i++) begin
                BHT[i] <= 0;
            end
        end else if(update) begin
            if(taken && BHT[PC_updt[7:2]] < 2'b11) begin
                BHT[PC_updt[7:2]] <= BHT[PC_updt[7:2]] + 1;
            end else if(!taken && BHT[PC_updt[7:2]] > 2'b00) begin
                BHT[PC_updt[7:2]] <= BHT[PC_updt[7:2]] - 1;
            end
        end
    end

    // return prediction
    always_comb begin
        prediction = BHT[PC_pred[7:2]][1];
    end

endmodule
