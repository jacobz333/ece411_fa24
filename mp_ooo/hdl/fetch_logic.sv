module fetch_logic
import rv32i_types::*;
#(
    parameter                   DEPTH_BITS = 8,
    parameter                   NSIZE = 1,
    localparam                  NSIZE_BITS = $clog2(NSIZE),
    localparam      logic[3:0]  NSIZE_SMALL = NSIZE
) (
    input   logic                   clk,
    input   logic                   rst,
    
    input   logic                   rob_flush,
 
    // icache ports
    output   logic   [31:0]  icache_ufp_addr,
    output   logic   [3:0]   icache_ufp_rmask,
    output   logic   [3:0]   icache_ufp_wmask,
    input    logic   [255:0] icache_ufp_rdata,
    output   logic   [31:0]  icache_ufp_wdata,
    input    logic           icache_ufp_resp,
    
    output   logic           move_pc,
    output   logic   [3:0]   move_amount,

    // IQ ports
    output   logic   [NSIZE-1:0]    enqueue,
    output   iq_entry_t             instructions[NSIZE],
    input    logic   [DEPTH_BITS:0] freespace,

    // PC ports
    input   logic   [31:0]          PC,
    input   logic   [31:0]          PC_next,
    input   logic   [63:0]          order
);
    logic        get_new_instruction;
    logic        invalidate_next_fetch;
    logic [3:0]  read_space;

    always_ff @ (posedge clk) begin
        if(rst) begin
            get_new_instruction <= '1;
            invalidate_next_fetch <= '0;
        end else if(rob_flush && !icache_ufp_resp && !get_new_instruction) begin
            invalidate_next_fetch <= '1;
        end else if(icache_ufp_resp && icache_ufp_rmask == '0) begin
            get_new_instruction <= '1;
            invalidate_next_fetch <= '0;
        end else if(icache_ufp_rmask != '0) begin
            get_new_instruction <= '0;
        end
    end
    
    int unsigned i;
    
    always_comb begin
        move_pc = '0;
        icache_ufp_wmask = '0;
        icache_ufp_wdata = 'x;
        icache_ufp_rmask = '0;
        icache_ufp_addr = 'x;
        enqueue = '0;
        
        
        read_space = 4'd8 - 4'(PC[4:2]);
        move_amount = '0; 
        if(32'(NSIZE) < 32'(read_space)) begin
            move_amount = 32'(freespace) < 32'(NSIZE) ? 4'(freespace) : NSIZE_SMALL;
        end else begin
            move_amount = 32'(freespace) < 32'(read_space) ? 4'(freespace) : read_space;
        end
        
        for(i = 0; i < NSIZE; i++) begin
            instructions[i] = 'x;
        end
        
        if(!rob_flush && !invalidate_next_fetch) begin
            if(icache_ufp_resp) begin
                icache_ufp_addr = {PC_next[31:5], 5'd0};
                move_pc = '1;
            end else begin
                icache_ufp_addr = {PC[31:5], 5'd0};
            end
            
            icache_ufp_rmask = {4{(get_new_instruction || icache_ufp_resp) && (freespace > (DEPTH_BITS+1)'(32'd1))}};
            
            
            if(icache_ufp_resp) begin
                for(i = 0; i < NSIZE; i++) begin
                    if(32'(i) >= 32'(move_amount)) begin
                        break;
                    end
                    instructions[i].instruction = icache_ufp_rdata[32 * (32'(PC[4:2]) + i) +: 32];
                    instructions[i].pc = PC + (i * 32'd4);
                    instructions[i].order = order + 64'(i);
                    enqueue[i] = 1'b1;
                    // Can't do these checks in the fetch stage anymore
                    // enqueue[i] = (instructions[i].instruction != '0) & (instructions[i].instruction != 32'h100073) & (instructions[i].instruction != 32'h73);
                end
            end
        end
    end
    
endmodule : fetch_logic
