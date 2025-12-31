/*
 * synchronous read/write register file
 */
module regfile
import rv32i_types::*;
#(
    parameter   PR_BITS = 5,        
    localparam  PR_NUM = 2**PR_BITS, // number of physical registers
    parameter   READ_PORT_NUM = 1,    // number of readout ports (addr1,2)
    parameter   CDB_COUNT = 1
) (
    input   logic                   clk,
    input   logic                   rst,
    
    input   logic   [PR_BITS-1:0]   ps1_addr[READ_PORT_NUM],
    input   logic   [PR_BITS-1:0]   ps2_addr[READ_PORT_NUM],

    output  logic   [31:0]          ps1_data[READ_PORT_NUM],
    output  logic   [31:0]          ps2_data[READ_PORT_NUM],
    
    input   cdb_t                   cdb[CDB_COUNT]
);
    logic   [31:0]          data[PR_NUM];

    always_ff @ (posedge clk) begin
        if (rst) begin
            for (int i = 0; i < PR_NUM; i++) begin
                data[i] <= '0;
            end
        end else begin
            for(int unsigned i = 0; i < CDB_COUNT; i++) begin
                if(cdb[i].ready && cdb[i].pr_dest != '0) begin
                    data[cdb[i].pr_dest] <= cdb[i].result;
                end
            end
        end
    end

    always_comb begin
        for (int i = 0; i < READ_PORT_NUM; i++) begin
            ps1_data[i] = data[ps1_addr[i]];
            ps2_data[i] = data[ps2_addr[i]];
        end
    end
endmodule
