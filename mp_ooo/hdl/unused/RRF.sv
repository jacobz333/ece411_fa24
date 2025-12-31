// Very similar to RAT, but with some uneeded signals removed
module RRF
#(
    parameter                   PHYS_BITS = 6,
    localparam                  PHYS_COUNT = 2 ** PHYS_BITS, 
    parameter                   ARCH_BITS = 5,
    localparam                  ARCH_COUNT = 2 ** ARCH_BITS,
    parameter                   NSIZE = 1,
    localparam                  NSIZE_BITS = $clog2(NSIZE)
)(
    input   logic                       clk,
    input   logic                       rst,

    input   logic   [ARCH_BITS-1:0]     alias_rd        [NSIZE],
    input   logic   [PHYS_BITS-1:0]     alias_pd        [NSIZE],
    input   logic                       alias_regf_we   [NSIZE],
    output  logic   [PHYS_BITS-1:0]     alias_pd_old    [NSIZE],

    output  logic   [PHYS_BITS-1:0]     alias_mem       [ARCH_COUNT]
);

    always_comb begin
        alias_pd_old[0] = alias_mem[alias_rd[0]];
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            for (integer unsigned i = 0; i < ARCH_COUNT; i++) begin
                alias_mem[i] <= (PHYS_BITS)'(i);
            end
        end else if (alias_regf_we[0]) begin
            alias_mem[alias_rd[0]] <= alias_pd[0];
        end
    end

endmodule

