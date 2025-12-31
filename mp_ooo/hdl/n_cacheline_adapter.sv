module n_cacheline_adapter
import rv32i_types::*;
#(
    parameter STREAM_BUFFER_SIZE = 3
)
(
    input   logic           clk,
    input   logic           rst,

    // bmem interface
    output  logic   [31:0]  bmem_addr,
    output  logic           bmem_read,
    output  logic           bmem_write,
    output  logic   [63:0]  bmem_wdata,
    input   logic           bmem_ready,

    input   logic   [31:0]  bmem_raddr,
    input   logic   [63:0]  bmem_rdata,
    input   logic           bmem_rvalid,

    // cache interface
    input   logic   [31:0]  dcache_addr,
    input   logic           dcache_read,
    input   logic           dcache_write,
    output  logic   [255:0] dcache_rdata,
    input   logic   [255:0] dcache_wdata,
    output  logic           dcache_resp,
    
    // cache interface
    input   logic   [31:0]  icache_addr,
    input   logic           icache_read,
    input   logic           icache_write,
    output  logic   [255:0] icache_rdata,
    input   logic   [255:0] icache_wdata,
    output  logic           icache_resp
);
    logic [31:0]  i_addr[STREAM_BUFFER_SIZE];
    logic [31:0]  d_addr;
    
    logic [255:0] d_buffer;
    logic [255:0] i_buffer[STREAM_BUFFER_SIZE];
    
    logic [1:0]   d_counter;
    
    logic i_addr_path_open;
    int unsigned i_addr_path_open_to;
    logic i_has_instruction;
    int unsigned i_instruction_at;
    logic i_waiting_on_instruction;
    int unsigned i_waiting_on_instruction_at;
    logic [1:0] i_counter;

    enum logic [2:0] {
        D_IDLE,
        D_WAIT_FOR_READ,
        D_BURSTING_READ,
        D_BURSTING_WRITE,
        D_WRITE_DONE,
        D_READ_DONE
    } dstate;

    enum logic [2:0] {
        I_IDLE,
        I_WAIT_TO_SEND_READ,
        I_WAIT_FOR_READ,
        I_BURSTING_READ,
        I_READ_DONE
    } istate[STREAM_BUFFER_SIZE];
    
    always_ff @(posedge clk) begin
        if(icache_write || icache_wdata != '0) begin end // Ignore 
        if(rst) begin
            d_buffer <= 'x;
            d_addr <= 'x;
            d_counter <= 2'b00;
            dstate <= D_IDLE;
            i_counter <= 2'b00;
            i_waiting_on_instruction <= 1'b0;
            i_waiting_on_instruction_at <= '0;
            for(int unsigned i = 0; i < STREAM_BUFFER_SIZE; i++) begin
                i_buffer[i] <= 'x;
                i_addr[i] <= 'x;
                istate[i] <= I_IDLE;
            end
        end else begin
        
            unique case(dstate)
                D_IDLE, D_WRITE_DONE, D_READ_DONE: begin
                    if(dcache_read) begin
                        dstate <= D_WAIT_FOR_READ;
                        d_addr <= dcache_addr;
                    end else if(dcache_write) begin
                        dstate <= D_BURSTING_WRITE;
                        d_buffer <= dcache_wdata;
                        d_addr <= dcache_addr;
                        if(bmem_ready) begin
                            d_counter <= d_counter + 2'd1;
                        end
                    end else begin
                        dstate <= D_IDLE;
                    end
                end
                D_BURSTING_WRITE: begin
                    if(bmem_ready) begin
                        d_counter <= d_counter + 2'd1;
                    end
                    if(d_counter == 2'd3) begin
                        d_counter <= 2'd0;
                        dstate <= D_WRITE_DONE;
                    end
                end
                D_WAIT_FOR_READ: begin
                    if(bmem_rvalid && bmem_raddr == d_addr) begin
                        d_counter <= d_counter + 2'd1;
                        dstate <= D_BURSTING_READ;
                        d_buffer[63:0] <= bmem_rdata;
                    end
                end
                D_BURSTING_READ: begin
                    d_counter <= d_counter + 2'd1;
                    d_buffer[64*d_counter +: 64] <= bmem_rdata;
                    if(d_counter == 2'd3) begin
                        d_counter <= 2'd0;
                        dstate <= D_READ_DONE;
                    end
                end
                default: begin
                end
            endcase
            
            if(i_waiting_on_instruction) begin
                if(istate[i_waiting_on_instruction_at] == I_READ_DONE) begin
                    i_waiting_on_instruction <= 1'b0;
                    istate[i_waiting_on_instruction_at] <= I_WAIT_TO_SEND_READ;
                    i_addr[i_waiting_on_instruction_at] <= i_addr[i_waiting_on_instruction_at] + STREAM_BUFFER_SIZE * 32'd32;
                end
            end else if(icache_read) begin
                if(i_has_instruction) begin
                    i_waiting_on_instruction <= 1'b1;
                    i_waiting_on_instruction_at <= i_instruction_at;
                end else begin
                    for(int unsigned i = 0; i < STREAM_BUFFER_SIZE; i++) begin
                        istate[i] <= I_WAIT_TO_SEND_READ;
                        i_addr[i] <= icache_addr + i * 32'd32;
                        i_buffer[i] <= 'x;
                    end
                    i_waiting_on_instruction <= 1'b1;
                    i_waiting_on_instruction_at <= '0;
                end
            end
            
            if(!icache_read || i_has_instruction || i_waiting_on_instruction) begin
                for(int unsigned i = 0; i < STREAM_BUFFER_SIZE; i++) begin
                    unique case(istate[i])
                        I_IDLE, I_READ_DONE: begin
                        end
                        I_WAIT_TO_SEND_READ: begin
                            if(i_addr_path_open && i_addr_path_open_to == i) begin
                                istate[i] <= I_WAIT_FOR_READ;
                            end
                        end
                        I_WAIT_FOR_READ: begin
                            if(bmem_rvalid && bmem_raddr == i_addr[i] && i_counter == '0) begin
                                istate[i] <= I_BURSTING_READ;
                                i_buffer[i][63:0] <= bmem_rdata;
                            end
                        end
                        I_BURSTING_READ: begin
                            i_buffer[i][64*i_counter +: 64] <= bmem_rdata;
                            if(i_counter == 2'd3) begin
                                istate[i] <= I_READ_DONE;
                            end
                        end
                        default: begin
                        end
                    endcase
                end
            end
            
            // If it isnt a data read address, then it must be for instructions
            // Start the instruction counter even if no instructions requested this data to prevent clashing
            if((bmem_rvalid && !(bmem_raddr == d_addr && (dstate == D_WAIT_FOR_READ || dstate == D_BURSTING_READ)) && i_counter == 2'd0) || (i_counter != 2'd0 && i_counter != 2'd3)) begin
                i_counter <= i_counter + 2'd1;
            end else if(i_counter == 2'd3) begin
                i_counter <= 2'd0;
            end
        end
    end
    
    always_comb begin
        bmem_write = 1'b0;
        bmem_read = 1'b0;
        icache_resp = 1'b0;
        icache_rdata = 'x;
        dcache_resp = 1'b0;
        dcache_rdata = 'x;
        bmem_addr = 'x;
        bmem_wdata = 'x;
        i_addr_path_open = 1'b0;
        i_addr_path_open_to = '0;
        i_has_instruction = 1'b0;
        i_instruction_at = '0;
        
        if(i_waiting_on_instruction) begin
            if(istate[i_waiting_on_instruction_at] == I_READ_DONE) begin
                icache_resp = 1'b1;
                icache_rdata = i_buffer[i_waiting_on_instruction_at];
            end
        end else if(icache_read) begin
            for(int unsigned i = 0; i < STREAM_BUFFER_SIZE; i++) begin
                if(icache_addr == i_addr[i] && istate[i] != I_IDLE) begin
                    i_has_instruction = 1'b1;
                    i_instruction_at = i;
                    break;
                end
            end
        end

        if(dstate == D_BURSTING_WRITE) begin
            bmem_wdata = d_buffer[64*d_counter +: 64];
            bmem_write = 1'b1;
            bmem_read = 1'b0;
            bmem_addr = d_addr;
        end else if((dcache_read || dcache_write) && (dstate == D_IDLE || dstate == D_WRITE_DONE || dstate == D_READ_DONE)) begin
            bmem_addr = dcache_addr;
            bmem_read = dcache_read;
            bmem_write = dcache_write;
            bmem_wdata = dcache_wdata[63:0];
        end else begin
            for(int unsigned i = 0; i < STREAM_BUFFER_SIZE; i++) begin
                if(istate[i] == I_WAIT_TO_SEND_READ) begin
                    bmem_addr = i_addr[i];
                    bmem_read = 1'b1;
                    i_addr_path_open = 1'b1;
                    i_addr_path_open_to = i;
                    break;
                end
            end
        end
        
        unique case(dstate)
            D_WRITE_DONE: begin
                dcache_resp = 1'b1;
            end
            D_READ_DONE: begin
                dcache_resp = 1'b1;
                dcache_rdata = d_buffer;
            end
            default: begin
            end
        endcase
    end

endmodule
