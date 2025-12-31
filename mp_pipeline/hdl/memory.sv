module memory
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,

    input   logic           stall, // this is generated outside!
    input   logic           valid,

    // data memory responses
    input   logic   [31:0]  dmem_rdata,
    input   logic           dmem_resp,
    // have we saved rd_data already?
    input   logic           saved_load_rd,
    output  logic   [31:0]  rd_data_load,

    // // regfile writes one cycle earlier
    // output  logic   [31:0]  regfile_rd_data,
    // output  logic   [4:0]   regfile_rd_addr,
    // output  logic           regfile_we,
    
    // stage registers
    input   ex_mem_stage_reg_t MEM_stage_reg,
    output  mem_wb_stage_reg_t WB_stage_reg,

    // RVFI monitors
    input   rvfi_t          MEM_rvfi_monitor,
    output  rvfi_t          WB_rvfi_monitor
);
            logic   [31:0]  load_addr;
            instr_t         inst;
            logic   [2:0]   funct3;
            logic   [4:0]   rd_s;
            // determine regfile writes
            logic           regf_we;
            logic   [31:0]  rd_v;
            // regfile
            logic   [31:0]  regfile_rd_data;
            logic   [4:0]   regfile_rd_addr;
            logic           regfile_we;

            // determine next valid
            logic           next_valid;
            // save rvfi dmem_rdata
            logic   [31:0]  saved_dmem_rdata;
        
    assign next_valid = valid & MEM_stage_reg.valid;

    assign load_addr = MEM_stage_reg.load_addr;
    assign inst = MEM_stage_reg.instr;
    assign funct3 = inst[14:12];
    assign rd_s = inst[11:7];
    assign rd_data_load = rd_v; // connected to rd data

    assign regfile_rd_addr = inst[11:7];
    
    always_comb begin
        if (saved_load_rd | ~MEM_stage_reg.load_instr) begin
            regfile_rd_data = MEM_stage_reg.rd_data;
        end else begin
            regfile_rd_data = rd_v;
        end

        // if (saved_load_rd) begin // if saved then use it
        //     regfile_rd_data = MEM_stage_reg.rd_data;
        // end else if (MEM_stage_reg.load_instr) begin // not saved, but loading
        //     regfile_rd_data = rd_v;
        // end else begin // otherwise use what exists
        //     regfile_rd_data = MEM_stage_reg.rd_data;
        // end
        // regfile_rd_data = (saved_load_rd & MEM_stage_reg.load_instr) ?  : rd_v;
    end

    always_comb begin
        regfile_we = 1'b0;
        rd_v    = 'x;

        unique case (inst.i_type.opcode)
            op_b_load: begin
                if (dmem_resp) begin
                    unique case (funct3)
                        load_f3_lb : rd_v = {{24{dmem_rdata[7 +8 *load_addr[1:0]]}}, dmem_rdata[8 *load_addr[1:0] +: 8 ]};
                        load_f3_lbu: rd_v = {{24{1'b0}}                            , dmem_rdata[8 *load_addr[1:0] +: 8 ]};
                        load_f3_lh : rd_v = {{16{dmem_rdata[15+16*load_addr[1]  ]}}, dmem_rdata[16*load_addr[1]   +: 16]};
                        load_f3_lhu: rd_v = {{16{1'b0}}                            , dmem_rdata[16*load_addr[1]   +: 16]};
                        load_f3_lw : rd_v = dmem_rdata;
                        default    : rd_v = 'x;
                    endcase
                    // pc_next = pc + 'd4;
                end
                regfile_we = valid & MEM_stage_reg.valid;
            end
            op_b_store: begin
                if (dmem_resp) begin
                    // pc_next = pc + 'd4;
                end
            end
            default: begin // do nothing

            end
        endcase
        
        regfile_we = regfile_we | MEM_stage_reg.regfile_we;
    end

    // updating writeback stage register
    always_ff @(posedge clk) begin
        if (rst) begin
            WB_stage_reg.pc         <= 'x;
            WB_stage_reg.valid      <= 1'b0;
        end else if (~stall) begin // pass through as normal
            WB_stage_reg.pc         <= MEM_stage_reg.pc;
            WB_stage_reg.valid      <= next_valid;
        end

        if (rst) begin
            WB_stage_reg.rd_addr    <= 'x;
            WB_stage_reg.rd_data    <= 'x;
            WB_stage_reg.regfile_we <= 1'b0;
        end else if (~stall & MEM_stage_reg.valid) begin // pass through as normal
            WB_stage_reg.rd_addr    <= MEM_stage_reg.rd_addr; // should be the same
            WB_stage_reg.rd_data    <= regfile_rd_data;
            WB_stage_reg.regfile_we <= regfile_we;
        end
    end

    // same dmem rdata for rvfi correctness
    always_ff @(posedge clk) begin
        if (rst) begin
            saved_dmem_rdata <= 'x;
        end else if (dmem_resp & stall) begin
            saved_dmem_rdata <= dmem_rdata;
        end else if (~stall) begin
            saved_dmem_rdata <= 'x;
        end
    end

    // updating rvfi monitor
    always_ff @(posedge clk) begin
        if (rst) begin
            WB_rvfi_monitor.valid     <= 1'b0;
            WB_rvfi_monitor.order     <= '0;
            WB_rvfi_monitor.inst      <= 'x;
            WB_rvfi_monitor.rs1_addr  <= 'x;
            WB_rvfi_monitor.rs2_addr  <= 'x;
            WB_rvfi_monitor.rs1_rdata <= 'x;
            WB_rvfi_monitor.rs2_rdata <= 'x;
            WB_rvfi_monitor.rd_addr   <= 'x;
            WB_rvfi_monitor.rd_wdata  <= 'x;
            WB_rvfi_monitor.pc_rdata  <= '0;
            WB_rvfi_monitor.pc_wdata  <= 'x;
            WB_rvfi_monitor.mem_addr  <= 'x;
            WB_rvfi_monitor.mem_rmask <= 'x;
            WB_rvfi_monitor.mem_wmask <= 'x;
            WB_rvfi_monitor.mem_rdata <= 'x;
            WB_rvfi_monitor.mem_wdata <= 'x;
        end else if (~stall) begin
            WB_rvfi_monitor.valid     <= MEM_rvfi_monitor.valid & valid;
            WB_rvfi_monitor.order     <= MEM_rvfi_monitor.order;
            WB_rvfi_monitor.inst      <= MEM_rvfi_monitor.inst;
            WB_rvfi_monitor.rs1_addr  <= MEM_rvfi_monitor.rs1_addr;
            WB_rvfi_monitor.rs2_addr  <= MEM_rvfi_monitor.rs2_addr;
            WB_rvfi_monitor.rs1_rdata <= MEM_rvfi_monitor.rs1_rdata;
            WB_rvfi_monitor.rs2_rdata <= MEM_rvfi_monitor.rs2_rdata;
            WB_rvfi_monitor.rd_addr   <= MEM_rvfi_monitor.rd_addr;   // zero rd monitor if not used!
            WB_rvfi_monitor.rd_wdata  <= regfile_rd_data;
            WB_rvfi_monitor.pc_rdata  <= MEM_rvfi_monitor.pc_rdata;
            WB_rvfi_monitor.pc_wdata  <= MEM_rvfi_monitor.pc_wdata;
            WB_rvfi_monitor.mem_addr  <= MEM_rvfi_monitor.mem_addr;
            WB_rvfi_monitor.mem_rmask <= MEM_rvfi_monitor.mem_rmask;
            WB_rvfi_monitor.mem_wmask <= MEM_rvfi_monitor.mem_wmask;
            WB_rvfi_monitor.mem_rdata <= saved_load_rd ? saved_dmem_rdata : dmem_rdata;
            WB_rvfi_monitor.mem_wdata <= MEM_rvfi_monitor.mem_wdata;
        end else begin
            WB_rvfi_monitor.valid     <= 1'b0; // RVFI only allows valid to be on in one cycle!
        end
    end

endmodule : memory