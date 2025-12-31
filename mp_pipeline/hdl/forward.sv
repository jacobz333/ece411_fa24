module forward(
    input   logic           clk,
    input   logic           rst,

    // requested by EX
    input   logic   [4:0]   rs1_addr_ex,
    input   logic   [4:0]   rs2_addr_ex,

    // data from regfile
    input   logic   [31:0]  rs1_data_regfile,
    input   logic   [31:0]  rs2_data_regfile,

    // rd to check and data to forward
    input   logic   [4:0]   rd_addr_mem,
    input   logic   [31:0]  rd_data_mem,
    input   logic   [4:0]   rd_addr_wb,
    input   logic   [31:0]  rd_data_wb,
    // flag to indicate when WB stage is updated
    input   logic           update_WB,
    input   logic           stall_EX,
    // load exception!
    input   logic           load_instr,
    input   logic           dmem_resp,
    input   logic           update_saved, 
    // flag to indicate that we've saved rd for loads already
    output  logic           saved,
    // input   logic   [31:0]  rd_data_mem_load,
    // tell MEM to stall because we need to forward rd
    output  logic           stall_load_rd,

    // data to forward to EX
    output  logic   [31:0]  rs1_data_ex,
    output  logic   [31:0]  rs2_data_ex
);
            // saving regfile readout
            logic           saved_regf_flag;
            logic   [31:0]  saved_regf_rs1_data;
            logic   [31:0]  saved_regf_rs2_data;
    // saving regfile readout
    always_ff @(posedge clk) begin
        if (rst) begin
            saved_regf_flag     <= 1'b0;
            saved_regf_rs1_data <= 'x;
            saved_regf_rs2_data <= 'x;
        end else if (stall_EX & ~saved_regf_flag) begin
            saved_regf_flag     <= 1'b1;
            saved_regf_rs1_data <= rs1_data_regfile;
            saved_regf_rs2_data <= rs2_data_regfile;
        end else if (~stall_EX) begin
            saved_regf_flag     <= 1'b0;
            saved_regf_rs1_data <= 'x;
            saved_regf_rs2_data <= 'x;
        end
    end

    assign stall_load_rd = (rs1_addr_ex == rd_addr_mem || rs2_addr_ex == rd_addr_mem) & load_instr & ~saved;

    always_ff @ (posedge clk) begin
        if (rst) begin
            saved <= 1'b0;
        end else if (update_saved) begin
            saved <= 1'b0;
        end else if ((rs1_addr_ex == rd_addr_mem || rs2_addr_ex == rd_addr_mem) & load_instr & dmem_resp) begin
            saved <= 1'b1;
        end
    end

    // always_comb begin
    //     // assign stall_mem_rd
    //     stall_load_rd = 1'b0;

    //     if ((rs1_addr_ex == rd_addr_mem || rs2_addr_ex == rd_addr_mem) & mem_load_flag) begin
    //         stall_load_rd = 1'b1;
    //     end
    // end
    //         logic   [4:0]   saved_rd_addr_mem;
    //         logic   [31:0]  saved_rd_data_mem;
    //         logic   [4:0]   saved_rd_addr_wb;
    //         logic   [31:0]  saved_rd_data_wb;

    // always_ff @ (posedge clk) begin
    //     if (rst) begin
    //         saved_rd_addr_mem <= 'x;
    //         saved_rd_data_mem <= 'x;
    //         saved_rd_addr_wb  <= 'x;
    //         saved_rd_data_wb  <= 'x;
    //     end else begin
    //         if (valid_EX) begin // execute stage is ready to propagate
    //             saved_rd_addr_mem <= 'x;
    //             saved_rd_data_mem <= 'x;
    //         end
    //         if (valid_MEM) begin // memory stage is ready to propagate
    //             saved_rd_addr_wb  <= 'x;
    //             saved_rd_data_wb  <= 'x;
    //         end
    //     end
    // end

    // rd data that is currently in regfile, but incorrectly read by execute
    logic   [4:0]     rd_addr_reg;
    logic   [31:0]    rd_data_reg;


    always_ff @ (posedge clk) begin
        if (rst) begin
            rd_addr_reg <= '0;
            rd_data_reg <= 'x;
        end else if (update_WB) begin
            rd_addr_reg <= rd_addr_wb;
            rd_data_reg <= rd_data_wb;
        end 
    end


    always_comb begin
        // defaults for safety
        rs1_data_ex = rs1_data_regfile;
        rs2_data_ex = rs2_data_regfile;

        if (saved_regf_flag) begin
            rs1_data_ex = saved_regf_rs1_data;
            rs2_data_ex = saved_regf_rs2_data;
        end

        if (rs1_addr_ex == 5'b0) begin
            rs1_data_ex = '0;
        end else if (rs1_addr_ex == rd_addr_mem) begin
            rs1_data_ex = rd_data_mem;
            // if (mem_load_flag) begin
            //     rs1_data_ex = rd_data_mem_load;
            // end else begin
                
            // end
        end else if (rs1_addr_ex == rd_addr_wb) begin
            rs1_data_ex = rd_data_wb;
        end else if (rs1_addr_ex == rd_addr_reg) begin
            rs1_data_ex = rd_data_reg;
        end

        if (rs2_addr_ex == 5'b0) begin
            rs2_data_ex = '0;
        end else if (rs2_addr_ex == rd_addr_mem) begin
            rs2_data_ex = rd_data_mem;
            // if (mem_load_flag) begin
            //     rs2_data_ex = rd_data_mem_load;
            // end else begin
            // end
        end else if (rs2_addr_ex == rd_addr_wb) begin
            rs2_data_ex = rd_data_wb;
        end else if (rs2_addr_ex == rd_addr_reg) begin
            rs2_data_ex = rd_data_reg;
        end
    end

endmodule