// Very similar to RAT, but with some uneeded signals removed
module RRF_n
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

    logic   [ARCH_BITS-1:0]     write_arch      [NSIZE];
    logic   [PHYS_BITS-1:0]     write_phys      [NSIZE];

    always_comb begin
        for(int unsigned i = 0; i < NSIZE; i++) begin
            alias_pd_old[i] = alias_mem[alias_rd[i]];
            for(int unsigned j = 0; j < i; j++) begin
                if(alias_regf_we[j]) begin
                    if(alias_rd[i] == alias_rd[j]) begin
                        alias_pd_old[i] = alias_pd[j];
                    end
                end
            end
        end
        
        for(int unsigned i = 0; i < NSIZE; i++) begin
            write_arch[i] = '0;
            write_phys[i] = '0;
            if(alias_regf_we[i] != '0) begin
                write_arch[i] = alias_rd[i];
                write_phys[i] = alias_pd[i];
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            for (integer unsigned i = 0; i < ARCH_COUNT; i++) begin
                alias_mem[i] <= (PHYS_BITS)'(i);
            end
        end else begin
            for(int unsigned i = 0; i < NSIZE; i++) begin
                if(write_arch[i] != '0) begin
                    alias_mem[write_arch[i]] <= write_phys[i];
                end
            end
        end
    end
    //logic                       valid_mem       [ARCH_COUNT];
    //logic   [PHYS_BITS-1:0]     alias_mem       [ARCH_COUNT];
    //
    //logic   [ARCH_BITS-1:0]     write_arch      [NSIZE];
    //logic   [PHYS_BITS-1:0]     write_phys      [NSIZE];
    //
    //logic   [PHYS_BITS-1:0]     write_rrf       [ARCH_COUNT];
    //
    //always_comb begin
    //    for(int unsigned i = 0; i < NSIZE; i++) begin
    //        alias_ps1[i] = alias_mem[alias_rs1[i]];
    //        alias_ps1_valid[i] = valid_mem[alias_rs1[i]];
    //        alias_ps2[i] = alias_mem[alias_rs2[i]];
    //        alias_ps2_valid[i] = valid_mem[alias_rs2[i]];
    //        for(int unsigned j = 0; j < i; j++) begin
    //            if(alias_regf_we[j]) begin
    //                if(alias_rs1[i] == alias_rd[j]) begin
    //                    alias_ps1[i] = alias_pd[j];
    //                    alias_ps1_valid[i] = '0;
    //                end
    //                if(alias_rs2[i] == alias_rd[j]) begin
    //                    alias_ps2[i] = alias_pd[j];
    //                    alias_ps2_valid[i] = '0;
    //                end
    //            end
    //        end
    //    end
    //    
    //    for(int unsigned i = 0; i < NSIZE; i++) begin
    //        write_arch[i] = '0;
    //        write_phys[i] = '0;
    //        if(alias_regf_we[i] != '0) begin
    //            write_arch[i] = alias_rd[i];
    //            write_phys[i] = alias_pd[i];
    //        end
    //    end
    //    
    //    for(int unsigned i = 0; i < ARCH_COUNT; i++) begin
    //        write_rrf[i] = '0;
    //    end
    //    for(int unsigned i = 0; i < NSIZE; i++) begin
    //        if(rrf_alias_regf_we[i] != '0) begin
    //            write_rrf[rrf_alias_rd[i]] = rrf_alias_pd[i];
    //        end
    //    end
    //end
    //
    //always_ff @(posedge clk) begin
    //    if (rst) begin
    //        for (integer unsigned i = 0; i < ARCH_COUNT; i++) begin
    //            valid_mem[i] <= '1;
    //            alias_mem[i] <= (PHYS_BITS)'(i); // All registers will start off pointing to register 0, as they have no mapping (they get a mapping after they are written into)
    //        end
    //    end else if (rob_flush) begin
    //        for (integer unsigned i = 0; i < ARCH_COUNT; i++) begin
    //            valid_mem[i] <= '1;
    //            if(write_rrf[i] != '0)
    //                alias_mem[i] <= write_rrf[i];
    //            else
    //                alias_mem[i] <= RRF_in[i];
    //        end
    //    end else begin
    //        for(int unsigned i = 0; i < CDB_COUNT; i++) begin
    //            if (global_cdb[i].ready) begin
    //                if (alias_mem[global_cdb[i].ar_dest] == global_cdb[i].pr_dest) begin
    //                    valid_mem[global_cdb[i].ar_dest] <= '1;
    //                end
    //            end
    //        end
    //        for(int unsigned i = 0; i < NSIZE; i++) begin
    //            if(write_arch[i] != '0) begin
    //                alias_mem[write_arch[i]] <= write_phys[i];
    //                valid_mem[write_arch[i]] <= '0;
    //            end
    //        end
    //    end
    //end
endmodule

