module fetch
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,

    input   logic           stall,
    input   logic           valid,

    output  logic           saved, // how we know the saved an instruction
    input   logic           stall_DE, // how we know when to load decode stage register

    input   logic   [31:0]  pc,
    input   logic   [31:0]  pc_next,

    // requesting from instruction memory
    output  logic   [31:0]  imem_addr,
    output  logic   [3:0]   imem_rmask,
    // reading from instruction memory
    input   logic   [31:0]  imem_rdata,
    input   logic           imem_resp,

    // decode stage register
    output  fe_de_stage_reg_t DE_stage_reg,

    // RVFI monitors
    input   logic   [63:0]  order,
    output  rvfi_t          DE_rvfi_monitor
);  
            
            instr_t         saved_instr; // saving instruction when stalled
            instr_t         instr;       // instruction to propagate. useful alias

    assign instr = saved ? saved_instr : imem_rdata;

    // assign instruction memory bus
    always_comb begin
        imem_rmask = 4'b0000;
        imem_addr = 'x;

        if (rst) begin // prefetch first instruction
            imem_rmask = 4'b1111;
            imem_addr = pc;
        end else if (~stall & ~rst) begin // if not stalled, then request next instruction
            imem_rmask = 4'b1111;
            imem_addr = pc_next;
        end
    end

    // updating save register
    always_ff @(posedge clk) begin
        if (rst) begin
            saved       <= 1'b0;
            saved_instr <= 'x;
        end else if (stall & imem_resp) begin // must save instruction
            saved       <= 1'b1;
            saved_instr <= imem_rdata;
        end else if (~stall) begin // clear when not stalled anymore
            saved       <= 1'b0;
            saved_instr <= 'x;
        end
    end

    // updating decode stage register
    always_ff @(posedge clk) begin
        if (rst) begin
            DE_stage_reg.instr <= 'x;
            DE_stage_reg.pc    <= 32'h1eceb004;
            DE_stage_reg.valid <= 1'b0;
        end else if (~stall_DE) begin // only load when not stalling decode
            DE_stage_reg.instr <= instr;
            DE_stage_reg.pc    <= pc;
            DE_stage_reg.valid <= valid; // TODO will involve branch_en
        end
    end

    // updating rvfi monitor
    always_ff @(posedge clk) begin
        if (rst) begin
            DE_rvfi_monitor.valid     <= 1'b0;
            DE_rvfi_monitor.order     <= '0;
            DE_rvfi_monitor.inst      <= 'x;
            DE_rvfi_monitor.rs1_addr  <= 'x;
            DE_rvfi_monitor.rs2_addr  <= 'x;
            DE_rvfi_monitor.rs1_rdata <= 'x;
            DE_rvfi_monitor.rs2_rdata <= 'x;
            DE_rvfi_monitor.rd_addr   <= 'x;
            DE_rvfi_monitor.rd_wdata  <= 'x;
            DE_rvfi_monitor.pc_rdata  <= pc;
            DE_rvfi_monitor.pc_wdata  <= 'x;
            DE_rvfi_monitor.mem_addr  <= 'x;
            DE_rvfi_monitor.mem_rmask <= 'x;
            DE_rvfi_monitor.mem_wmask <= 'x;
            DE_rvfi_monitor.mem_rdata <= 'x;
            DE_rvfi_monitor.mem_wdata <= 'x;
        end else if (~stall_DE) begin
            DE_rvfi_monitor.valid     <= valid;
            DE_rvfi_monitor.order     <= order;
            DE_rvfi_monitor.inst      <= instr;
            DE_rvfi_monitor.rs1_addr  <= 'x;
            DE_rvfi_monitor.rs2_addr  <= 'x;
            DE_rvfi_monitor.rs1_rdata <= 'x;
            DE_rvfi_monitor.rs2_rdata <= 'x;
            DE_rvfi_monitor.rd_addr   <= 'x;
            DE_rvfi_monitor.rd_wdata  <= 'x;
            DE_rvfi_monitor.pc_rdata  <= pc;
            DE_rvfi_monitor.pc_wdata  <= 'x; // determined in execute stage
            DE_rvfi_monitor.mem_addr  <= 'x;
            DE_rvfi_monitor.mem_rmask <= 'x;
            DE_rvfi_monitor.mem_wmask <= 'x;
            DE_rvfi_monitor.mem_rdata <= 'x;
            DE_rvfi_monitor.mem_wdata <= 'x;
        end
    end

endmodule : fetch