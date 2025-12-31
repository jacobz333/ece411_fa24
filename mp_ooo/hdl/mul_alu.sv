module mul_alu
import rv32i_types::*;
#(
    localparam  DATA_WIDTH  = 32,  
    localparam  DELAY       = 3     
    // if request is given at cycle 0, we receive product at cycle DELAY-1
) (
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
    // to alu/cdb
    output  cdb_t                       cdb,
    input   logic                       stall
);
// u for unsigned, s for signed
            // unified starts and completes
            logic                       start;
            logic                       complete;
            // connections to multiplier and divider IPs
            logic                       u_mult_complete, s_mult_complete;
            logic   [2*DATA_WIDTH-1:0]  u_product;
            logic   [2*DATA_WIDTH+1:0]  s_product;
            logic   [  DATA_WIDTH-1:0]  u_quotient, s_quotient;
            logic   [  DATA_WIDTH-1:0]  u_remainder, s_remainder;
            // pipeline stage register for execution
            logic   [31:0]              ps1_data_reg;
            logic   [31:0]              ps2_data_reg;
            rs_entry_t                  rs_entry_reg;
            logic                       valid_reg;
            // choose operation and result
            logic   [2:0]               mul_div_op;
            logic   [31:0]              mult_div_out;
            // mulhsu support
            logic   [32:0]              s_mult_in1, s_mult_in2;
    
    assign complete = u_mult_complete | s_mult_complete;
    assign mul_div_op = rs_entry_reg.funct3;

    // assign mult_div_out result
    always_comb begin
        s_mult_in1   = {ps1_data_reg[31], ps1_data_reg}; // default is to sign extend inputs
        s_mult_in2   = {ps2_data_reg[31], ps2_data_reg};
        unique case (mul_div_op)
            mult_div_op_mul   : mult_div_out = s_product[31: 0];
            mult_div_op_mulh  : mult_div_out = s_product[63:32];
            mult_div_op_mulhsu: begin
                s_mult_in1   = {ps1_data_reg[31], ps1_data_reg};
                s_mult_in2   = {            1'b0, ps2_data_reg};
                mult_div_out = s_product[63:32];
            end
            mult_div_op_mulhu : mult_div_out = u_product[63:32];
            default           : mult_div_out = 'x; // should never happen
        endcase
    end

    // assign stage reg
    always_ff @ (posedge clk) begin
        if (rst) begin
            valid_reg <= 1'b0;
        end else if (ready) begin
            valid_reg <= rs_entry_valid;
        end
        if (ready) begin
            ps1_data_reg <= ps1_data;
            ps2_data_reg <= ps2_data;
            rs_entry_reg <= rs_entry_dout;
        end
    end
    
    // assign start
    always_ff @ (posedge clk) begin
        if (rst) begin
            start <= 1'b0;
        end else if (ready) begin
            start <= rs_entry_valid; // start operation if incoming rs_entry is valid
        end else if (start) begin // deassert start after its on for one cycle
            start <= 1'b0;
        end
    end

    // assign ready
    assign ready = complete & ~stall & ~start;

    // assign cdb
    always_comb begin
        cdb.ready               = valid_reg & complete & ~start;
        cdb.rob_id              = rs_entry_reg.rob_id;
        cdb.ar_dest             = rs_entry_reg.rd_addr;
        cdb.pr_dest             = rs_entry_reg.pd_addr;
        cdb.result              = mult_div_out;
        cdb.monitor_rs1_rdata   = ps1_data_reg;
        cdb.monitor_rs2_rdata   = ps2_data_reg;
        cdb.monitor_mem_rmask   = '0;
        cdb.monitor_mem_rdata   = 'x;
        cdb.monitor_mem_addr    = 'x;
    end

    DW_mult_seq #(
        .a_width(DATA_WIDTH),   // input bit widths
        .b_width(DATA_WIDTH),
        .tc_mode(0),            // unsigned
        .num_cyc(DELAY),        // number of cycles delayed (must be greater than 3)
        .rst_mode   (1),        // synchronous reset
        .input_mode (0),        // non registered inputs
        .output_mode(1),        // registered outputs
        .early_start(0)         // see table 1-6.
    ) u_mult_seq (
        .clk    ( clk),
        .rst_n  (~rst),     // active low
        .hold   ('0),
        .start  (start),
        .a      (ps1_data_reg),        // inputs
        .b      (ps2_data_reg),   
        .complete(u_mult_complete),        
        .product (u_product)   // product
    );

    DW_mult_seq #(
        .a_width(DATA_WIDTH+1), // input bit widths
        .b_width(DATA_WIDTH+1),
        .tc_mode(1),            // signed
        .num_cyc(DELAY),        // number of cycles delayed (must be greater than 3)
        .rst_mode   (1),        // synchronous reset
        .input_mode (0),        // non registered inputs
        .output_mode(1),        // registered outputs
        .early_start(0)         // see table 1-6.
    ) s_mult_seq (
        .clk    ( clk),
        .rst_n  (~rst),         // active low
        .hold   ('0),
        .start  (start),
        .a      (s_mult_in1),            // inputs
        .b      (s_mult_in2),   
        .complete(s_mult_complete),        
        .product (s_product)   // product
    );

endmodule
