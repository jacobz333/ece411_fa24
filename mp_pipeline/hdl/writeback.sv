module writeback
import rv32i_types::*;
(
    // input   logic           clk,
    input   logic           rst,

    // input   logic           valid,

    // write to regfile
    output  logic           regf_we,
    output  logic   [4:0]   rd_s,
    output  logic   [31:0]  rd_v,

    // stage register
    input   mem_wb_stage_reg_t WB_stage_reg

    // RVFI monitors
    // input   rvfi_t          WB_rvfi_monitor
    // output  rvfi_t          rvfi_monitor
);

    always_comb begin
        rd_s = WB_stage_reg.rd_addr;
        rd_v = WB_stage_reg.rd_data;
        if (rst | ~WB_stage_reg.valid) begin
            regf_we = 1'b0;
        end else begin
            regf_we = WB_stage_reg.regfile_we;
        end
    end

endmodule: writeback