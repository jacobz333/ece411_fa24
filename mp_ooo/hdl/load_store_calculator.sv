module load_store_calculator
import rv32i_types::*;
#(
    parameter                   NSIZE = 1,
    localparam                  NSIZE_BITS = $clog2(NSIZE)
) 
(
    input   logic                       clk,
    input   logic                       rst,        // active high
    // from reservation station
    input   logic                       rs_entry_valid,
    input   rs_entry_t                  rs_entry_dout,
    // to reservation station
    output  logic                       ready,      // accepting reservation station requests (=1)
    // from regfile
    input   logic   [31:0]              ps1_data,
    input   logic   [31:0]              ps2_data,
    // to load store queue
    output  lsq_bus_t                   lsq_bus
);
    // pipeline stage register for execution
    logic   [31:0]              ps1_data_reg;
    logic   [31:0]              ps2_data_reg;
    rs_entry_t                  rs_entry_reg;
    logic                       valid_reg;
            
    assign ready = ~rst; // should always be ready

    // assign stage reg
    always_ff @ (posedge clk) begin
        if (rst) begin
            valid_reg <= 1'b0;
            ps1_data_reg <= 'x;
            ps2_data_reg <= 'x;
            rs_entry_reg <= 'x;               
        end else if (ready) begin
            valid_reg <= rs_entry_valid;
            ps1_data_reg <= ps1_data;
            ps2_data_reg <= ps2_data;
            rs_entry_reg <= rs_entry_dout;
        end
    end

    always_comb begin
        lsq_bus.lsq_id = rs_entry_reg.lsq_id;
        lsq_bus.mask = 'x;
        lsq_bus.addr = 'x;
        lsq_bus.wdata = 'x;
        lsq_bus.monitor_rs1_rdata = ps1_data_reg;
        lsq_bus.monitor_rs2_rdata = ps2_data_reg;

        unique case(rs_entry_reg.opcode)
            op_b_load: begin
                lsq_bus.addr = ps1_data_reg + rs_entry_reg.imm;
                
                unique case (rs_entry_reg.funct3)
                    load_f3_lb, load_f3_lbu: lsq_bus.mask = 4'b0001 << lsq_bus.addr[1:0];
                    load_f3_lh, load_f3_lhu: lsq_bus.mask = 4'b0011 << lsq_bus.addr[1:0];
                    load_f3_lw             : lsq_bus.mask = 4'b1111;
                    default                : lsq_bus.mask = 'x;
                endcase
            end
            op_b_store: begin
                lsq_bus.addr = ps1_data_reg + rs_entry_reg.imm;
                
                unique case (rs_entry_reg.funct3)
                    store_f3_sb: lsq_bus.mask = 4'b0001 << lsq_bus.addr[1:0];
                    store_f3_sh: lsq_bus.mask = 4'b0011 << lsq_bus.addr[1:0];
                    store_f3_sw: lsq_bus.mask = 4'b1111;
                    default    : lsq_bus.mask = 'x;
                endcase
                unique case (rs_entry_reg.funct3)
                    store_f3_sb: lsq_bus.wdata[8 *lsq_bus.addr[1:0] +: 8 ] = ps2_data_reg[7 :0];
                    store_f3_sh: lsq_bus.wdata[16*lsq_bus.addr[1]   +: 16] = ps2_data_reg[15:0];
                    store_f3_sw: lsq_bus.wdata = ps2_data_reg;
                    default    : lsq_bus.wdata = 'x;
                endcase
            end
            default: begin
            end
        endcase
        
        lsq_bus.ready = valid_reg;
    end

endmodule
