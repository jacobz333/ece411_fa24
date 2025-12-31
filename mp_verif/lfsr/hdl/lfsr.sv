module lfsr #(
    parameter bit   [15:0]  SEED_data = 'hECEB
) (
    input   logic           clk,
    input   logic           rst,
    input   logic           en,
    output  logic           rand_bit,
    output  logic   [15:0]  shift_reg
);

    // TODO: Fill this out!
    logic unsigned [15:0] data;

    // assign outputs
    assign shift_reg = data;

    // assign data and rand_bit
    always_ff @(posedge clk) begin
        rand_bit <= 1'bX;
        if (rst) begin // reset to seed
            data <= SEED_data;
        end else if (en) begin // shift when enabled
            data <= {data[5] ^ (data[3] ^ (data[2] ^ data[0])), // XOR with tap bits
                     data[15:1]};
            rand_bit <= data[0];
        end
    end

endmodule : lfsr
