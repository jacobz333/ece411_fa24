class RATRandGen #(
    parameter                   PHYS_BITS = 6,
    parameter                   ARCH_BITS = 5,
    parameter                   SUPE_WAYS = 1
);
    rand bit    [ARCH_BITS-1:0] rd;
    rand bit    [PHYS_BITS-1:0] pd;
    rand bit    [ARCH_BITS-1:0] rs1;
    rand bit    [ARCH_BITS-1:0] rs2;
    rand bit                    regf_we;
endclass

module rat_tb;
    timeunit 1ps;
    timeprecision 1ps;

    localparam                  PHYS_BITS = 6;
    localparam                  ARCH_BITS = 5;
    localparam                  SUPE_WAYS = 1;

    bit clk, rst, verbose;
    
    logic   [ARCH_BITS-1:0]     alias_rd        [SUPE_WAYS];
    logic   [PHYS_BITS-1:0]     alias_pd        [SUPE_WAYS];
    logic                       alias_regf_we   [SUPE_WAYS];

    logic   [ARCH_BITS-1:0]     alias_rs1       [SUPE_WAYS];

    logic   [PHYS_BITS-1:0]     alias_ps1       [SUPE_WAYS];
    logic                       alias_ps1_valid [SUPE_WAYS];

    logic   [ARCH_BITS-1:0]     alias_rs2       [SUPE_WAYS];

    logic   [PHYS_BITS-1:0]     alias_ps2       [SUPE_WAYS];
    logic                       alias_ps2_valid [SUPE_WAYS];

    logic   [ARCH_BITS-1:0]     valid_rd        [SUPE_WAYS];
    logic   [PHYS_BITS-1:0]     valid_pd        [SUPE_WAYS];
    logic                       valid_regf_we   [SUPE_WAYS];

    RAT #(.PHYS_BITS(PHYS_BITS), .ARCH_BITS(ARCH_BITS), .SUPE_WAYS(SUPE_WAYS)) dut (.*);

    RATRandGen #(.PHYS_BITS(PHYS_BITS), .ARCH_BITS(ARCH_BITS), .SUPE_WAYS(SUPE_WAYS)) dispatch_gen;
    RATRandGen #(.PHYS_BITS(PHYS_BITS), .ARCH_BITS(ARCH_BITS), .SUPE_WAYS(SUPE_WAYS)) CDB_gen;

    always #1 clk = ~clk;

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst = 1'b1;
        repeat (2) @(negedge clk);
        rst = 1'b0;
    end

    task random_t();
        for (integer i = 0; i < 100; i++) begin
            dispatch_gen.randomize();
            CDB_gen.randomize();
            
            alias_rd[0] = dispatch_gen.rd;
            alias_pd[0] = dispatch_gen.pd;
            alias_regf_we[0] = dispatch_gen.regf_we;
            alias_rs1[0] = dispatch_gen.rs1;
            alias_rs2[0] = dispatch_gen.rs2;

            valid_rd[0] = CDB_gen.rd;
            valid_pd[0] = CDB_gen.pd;
            valid_regf_we[0] = CDB_gen.regf_we;

            @(negedge clk);
        end
    endtask

    initial begin
        dispatch_gen = new;
        CDB_gen = new;
        @(negedge rst);

        verbose = '0;

        random_t();

        @(negedge clk);
        $display("SIMULATION SUCCESS");
        $finish;
    end
endmodule
