//-----------------------------------------------------------------------------
// Title                 : random_tb
// Project               : ECE 411 mp_verif
//-----------------------------------------------------------------------------
// File                  : random_tb.sv
// Author                : ECE 411 Course Staff
//-----------------------------------------------------------------------------
// IMPORTANT: If you don't change the random seed, every time you do a `make run`
// you will run the /same/ random test. SystemVerilog calls this "random stability",
// and it's to ensure you can reproduce errors as you try to fix the DUT. Make sure
// to change the random seed or run more instructions if you want more extensive
// coverage.
//------------------------------------------------------------------------------
module random_tb;

    timeunit 1ps;
    timeprecision 1ps;
    
    `include "../../hvl/vcs/randinst.svh"

    int clock_half_period_ps;
    longint timeout = 64'd10000;
    // initial begin
        // $value$plusargs("CLOCK_PERIOD_PS_ECE411=%d", clock_half_period_ps);
        // clock_half_period_ps = clock_half_period_ps / 2;
    //     $value$plusargs("TIMEOUT_ECE411=%d", timeout);
    // end

    bit clk;
    always #10 clk = ~clk;
    
    bit rst;

    mem_itf_banked mem_itf(.*);
    
    RandInst gen = new();
    RandInst gen2 = new();
    
    int true_index;
    int true_index_1;
    
    logic [31:0] address_read;
    
    // Do a bunch of LUIs to get useful register state.
    task init_register_state();
        for (int i = 0; i < 4; ++i) begin
            mem_itf.rdata <= 'x;
            mem_itf.raddr <= 'x;
            mem_itf.rvalid <= 1'b0;
            @(posedge mem_itf.clk iff |mem_itf.read);
            address_read <= mem_itf.addr;
            
            repeat (12) begin
                @(posedge mem_itf.clk);
            end
            
            mem_itf.raddr <= address_read;
            mem_itf.rvalid <= 1'b1;
            for(int j = 0; j < 4; ++j) begin
                true_index = i * 8 + j * 2;
                true_index_1 = i * 8 + j * 2 + 1;
                
                gen.randomize() with {
                    instr.j_type.opcode == op_b_lui;
                    instr.j_type.rd == true_index[4:0];
                };
                
                gen2.randomize() with {
                    instr.j_type.opcode == op_b_lui;
                    instr.j_type.rd == true_index_1[4:0];
                };

                // Your code here: package these memory interactions into a task.
                mem_itf.rdata <= {gen.instr.word, gen2.instr.word};
                @(posedge mem_itf.clk);
            end
        end
        mem_itf.rdata <= 'x;
        mem_itf.raddr <= 'x;
        mem_itf.rvalid <= 1'b0;
    endtask : init_register_state

    // Note that this memory model is not consistent! It ignores
    // writes and always reads out a random, valid instruction.
    
    task run_random_instrs();
        for (int i = 0; i < 10000; ++i) begin
            mem_itf.rdata <= 'x;
            mem_itf.raddr <= 'x;
            mem_itf.rvalid <= 1'b0;
            @(posedge mem_itf.clk iff |mem_itf.read);
            address_read <= mem_itf.addr;
            
            repeat (12) begin
                @(posedge mem_itf.clk);
            end
            
            mem_itf.raddr <= address_read;
            mem_itf.rvalid <= 1'b1;
            for(int j = 0; j < 4; ++j) begin
                true_index = i * 8 + j * 2;
                true_index_1 = i * 8 + j * 2 + 1;
                
                gen.randomize() with {
                    (instr.j_type.opcode == op_b_lui || instr.j_type.opcode == op_b_imm || instr.j_type.opcode == op_b_reg || instr.j_type.opcode == op_b_auipc);
                };
                
                gen2.randomize() with {
                    (instr.j_type.opcode == op_b_lui || instr.j_type.opcode == op_b_imm || instr.j_type.opcode == op_b_reg || instr.j_type.opcode == op_b_auipc);
                };

                // Your code here: package these memory interactions into a task.
                mem_itf.rdata <= {gen.instr.word, gen2.instr.word};
                @(posedge mem_itf.clk);
            end
        end
        mem_itf.rdata <= 'x;
        mem_itf.raddr <= 'x;
        mem_itf.rvalid <= 1'b0;
    endtask : run_random_instrs

    mon_itf #(.CHANNELS(8)) mon_itf(.*);
    monitor #(.CHANNELS(8)) monitor(.itf(mon_itf));

    cpu dut(
        .clk            (clk),
        .rst            (rst),

        .bmem_addr  (mem_itf.addr  ),
        .bmem_read  (mem_itf.read  ),
        .bmem_write (mem_itf.write ),
        .bmem_wdata (mem_itf.wdata ),
        .bmem_ready (mem_itf.ready ),
        .bmem_raddr (mem_itf.raddr ),
        .bmem_rdata (mem_itf.rdata ),
        .bmem_rvalid(mem_itf.rvalid)
    );

    `include "rvfi_reference.svh"

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
        
        $display("Initializing all registers to some value");
        init_register_state();
        
        $display("Running random instructions");
        run_random_instrs();
        
        repeat (100) @(posedge clk);
        
        $finish;
    end

//     always @(posedge clk) begin
//         for (int unsigned i=0; i < 8; ++i) begin
//             if (mon_itf.halt[i]) begin
//                 $finish;
//             end
//         end
//         
//         if (timeout == 0) begin
//             $error("TB Error: Timed out");
//             $finish;
//         end
//         
//         if (mon_itf.error != 0) begin
//             repeat (5) @(posedge clk);
//             $finish;
//         end
//         
//         if (mem_itf.error != 0) begin
//             repeat (5) @(posedge clk);
//             $finish;
//         end
//         
//         timeout <= timeout - 1;
//     end

endmodule : random_tb
