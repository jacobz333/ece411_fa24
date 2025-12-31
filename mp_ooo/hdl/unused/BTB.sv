/* 
    Note: Fully Associative BTB, update logic not implemented
*/
module BTB #(
    parameter   BTB_DEPTH=5
)(
    input   logic           clk,
    input   logic           rst,
    input   logic   [31:0]  BTB_PC,
    input   logic   [31:0]  BTB_PC_update,
    input   logic           BTB_update_valid,
    output  logic   [31:0]  BTB_PC_target,
    output  logic           BTB_target_valid
);
            logic           valid           [BTB_DEPTH];
            logic   [31:0]  source          [BTB_DEPTH];
            logic   [31:0]  target          [BTB_DEPTH];

    always_comb begin
        BTB_target_valid = '0;
        for(int i=0; i<BTB_DEPTH; i++) begin
            if (source[i] == BTB_PC) begin
                BTB_target_valid = valid[i];
                BTB_PC_target = target[i];
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            for(int i=0; i<BTB_DEPTH; i++) begin
                valid[i] = '0;
            end
        end else begin
            // find victim with pLRU
        end
    end
    
endmodule
