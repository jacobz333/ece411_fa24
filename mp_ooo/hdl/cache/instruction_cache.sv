module instruction_cache (
    input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    output  logic   [255:0] ufp_rdata,
    input   logic   [31:0]  ufp_wdata,
    output  logic           ufp_resp,

    // memory side signals, dfp -> downward facing port
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    input   logic   [255:0] dfp_rdata,
    output  logic   [255:0] dfp_wdata,
    input   logic           dfp_resp
);
    logic        valid_bit[4];
    logic        dirties[4];
    logic [22:0] tags[4];
    logic [255:0] datas[4];

    logic [3:0]  ufp_addr_set_index;
    logic [4:0]  ufp_addr_byte_offset;
    logic [22:0] ufp_addr_tag;

    assign ufp_addr_set_index = ufp_addr[8:5];
    assign ufp_addr_byte_offset = ufp_addr[4:0];
    assign ufp_addr_tag = ufp_addr[31:9];

    logic [31:0] ufp_addr_reg;
    logic [3:0]  ufp_rmask_reg;
    logic [3:0]  ufp_wmask_reg;
    logic [31:0] ufp_wdata_reg;

    logic [3:0]  ufp_addr_set_index_reg;
    logic [4:0]  ufp_addr_byte_offset_reg;
    logic [22:0] ufp_addr_tag_reg;
    logic [7:0]  ufp_addr_bit_offset_reg;

    assign ufp_addr_set_index_reg = ufp_addr_reg[8:5];
    assign ufp_addr_byte_offset_reg = ufp_addr_reg[4:0];
    assign ufp_addr_tag_reg = ufp_addr_reg[31:9];

    logic [3:0]  way_selected;

    logic       write_to_lru;
    logic [2:0] write_to_lru_data;
    logic [3:0] write_to_lru_addr;
    logic [2:0] read_from_lru_data;

    logic       clean_miss;
    logic       clean_miss_waiting_for_resp;
    logic       clean_miss_resp_received;
    logic       post_clean_miss; // Wait after a response was received post read miss for 2 cycles (1 cycle needed to write to SRAM, 1 cycle to reread stuff and create a ufp response)
    logic [1:0] way_to_write_to_post_miss;
    logic [1:0] way_to_write_to_post_miss_reg;

    logic         dirty_miss;
    logic         dirty_miss_waiting_for_resp;
    logic         dirty_miss_resp_received;
    logic [255:0] dirty_miss_data_to_write;
    logic [22:0]  dirty_miss_tag_to_write_to;
    logic [255:0] dirty_miss_data_to_write_reg;
    logic [22:0]  dirty_miss_tag_to_write_to_reg;


    assign ufp_addr_bit_offset_reg = ufp_addr_byte_offset_reg << 3; 
    
    logic write_hit_stall_reg;
    logic actual_write_hit;
    logic post_write_hit_stall_reg;


    logic [255:0] data_array_din0[4];
    logic         data_array_web0[4];
    logic [31:0]  data_array_wmask0[4];
    
    logic [23:0]  tag_array_din0[4];
    logic         tag_array_web0[4]; 

    logic         valid_array_web0[4];

    logic [3:0]   general_array_addr0;

    assign clean_miss_resp_received = dfp_resp && clean_miss_waiting_for_resp;
    assign dirty_miss_resp_received = dfp_resp && dirty_miss_waiting_for_resp;

    generate for (genvar i = 0; i < 4; i++) begin : select_way
        assign way_selected[i] = valid_bit[i] && (tags[i] == ufp_addr_tag_reg); // Previous cycle was a hit 
    end endgenerate

    assign actual_write_hit = write_hit_stall_reg && (way_selected != 4'b0000);

    always_comb begin
        if(clean_miss_resp_received || post_clean_miss || actual_write_hit || post_write_hit_stall_reg) begin
            general_array_addr0 = ufp_addr_set_index_reg; 
        end else begin
            general_array_addr0 = ufp_addr_set_index;
        end
    end

    generate for (genvar i = 0; i < 4; i++) begin : arrays
        always_comb begin
            if(clean_miss_resp_received) begin
                data_array_web0[i] = (i[1:0] != way_to_write_to_post_miss_reg); 
                data_array_din0[i] = dfp_rdata;
                data_array_wmask0[i] = '1;
                tag_array_web0[i] = (i[1:0] != way_to_write_to_post_miss_reg);
                tag_array_din0[i] = {1'b0, ufp_addr_tag_reg}; // New cache line from memory, starts with a 0 dirty bit
                valid_array_web0[i] = (i[1:0] != way_to_write_to_post_miss_reg);
            end else if(post_clean_miss && ufp_wmask_reg != '0) begin
                data_array_web0[i] = (i[1:0] != way_to_write_to_post_miss_reg);
                data_array_din0[i] = {224'b0, ufp_wdata_reg} << ufp_addr_bit_offset_reg; 
                data_array_wmask0[i] = {28'b0, ufp_wmask_reg} << ufp_addr_byte_offset_reg;
                tag_array_web0[i] = (i[1:0] != way_to_write_to_post_miss_reg);
                tag_array_din0[i] = {1'b1, ufp_addr_tag_reg}; // Write occurred, now cache line is dirty
                valid_array_web0[i] = 1'b1;
            end else if(actual_write_hit) begin
                data_array_web0[i] = !(valid_bit[i] && (tags[i] == ufp_addr_tag_reg));
                data_array_din0[i] = {224'b0, ufp_wdata_reg} << ufp_addr_bit_offset_reg; 
                data_array_wmask0[i] = {28'b0, ufp_wmask_reg} << ufp_addr_byte_offset_reg;
                tag_array_web0[i] = !(valid_bit[i] && (tags[i] == ufp_addr_tag_reg));
                tag_array_din0[i] = {1'b1, tags[i]}; // Write occurred, now cache line is dirty
                valid_array_web0[i] = 1'b1;
            end else begin
                data_array_web0[i] = 1'b1;
                data_array_din0[i] = 'x;
                data_array_wmask0[i] = 'x;
                tag_array_web0[i] = 1'b1;
                tag_array_din0[i] = 'x;
                valid_array_web0[i] = 1'b1;
            end
        end

        mp_cache_data_array data_array (
            .clk0       (clk),
            .csb0       (1'b0),
            .web0       (data_array_web0[i]),
            .wmask0     (data_array_wmask0[i]),
            .addr0      (general_array_addr0),
            .din0       (data_array_din0[i]),
            .dout0      (datas[i])
        );
        mp_cache_tag_array tag_array (
            .clk0       (clk),
            .csb0       (1'b0),
            .web0       (tag_array_web0[i]),
            .addr0      (general_array_addr0),
            .din0       (tag_array_din0[i]),
            .dout0      ({dirties[i], tags[i]})
        );
        valid_array valid_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       (1'b0),
            .web0       (valid_array_web0[i]),
            .addr0      (general_array_addr0),
            .din0       (~rst),
            .dout0      (valid_bit[i])
        );
    end endgenerate

    // Way A = Least significant way, Way D = Most significant way
    // LRU data = L2L1L0
    // Each level bit shows most recently visited
    // L0 = A/B is 0, C/D is 1
    // L1 = A is 0, B is 1
    // L2 = C is 0, D is 1 
 
    always_comb begin
        ufp_rdata = 'x;
        write_to_lru = 1'b1;
        ufp_resp = 1'b0;
        write_to_lru_addr = 'x;
        write_to_lru_data = 'x;
        clean_miss = 1'b0;
        way_to_write_to_post_miss = 2'bxx;
        dirty_miss_data_to_write = 'x;
        dirty_miss_tag_to_write_to = 'x;
        dirty_miss = 1'b0;
        if(!clean_miss_waiting_for_resp && !dirty_miss_waiting_for_resp && !post_clean_miss && (ufp_rmask_reg != '0 || ufp_wmask_reg != '0) && !post_write_hit_stall_reg) begin
            if(way_selected != '0) begin
                write_to_lru = 1'b0;
                write_to_lru_addr = ufp_addr_set_index_reg;
                ufp_resp = 1'b1;
            end
            unique case(way_selected)
                4'b0001: begin
                    write_to_lru_data[0] = 1'b0;
                    write_to_lru_data[1] = 1'b0;
                    write_to_lru_data[2] = read_from_lru_data[2];
                    if(ufp_rmask_reg != '0) begin
                        ufp_rdata = datas[0];
                    end
                end
                4'b0010: begin
                    write_to_lru_data[0] = 1'b0;
                    write_to_lru_data[1] = 1'b1;
                    write_to_lru_data[2] = read_from_lru_data[2]; 
                    if(ufp_rmask_reg != '0) begin
                        ufp_rdata = datas[1];
                    end
                end
                4'b0100: begin
                    write_to_lru_data[0] = 1'b1;
                    write_to_lru_data[1] = read_from_lru_data[1];
                    write_to_lru_data[2] = 1'b0;
                    if(ufp_rmask_reg != '0) begin
                        ufp_rdata = datas[2];
                    end
                end
                4'b1000: begin
                    write_to_lru_data[0] = 1'b1;
                    write_to_lru_data[1] = read_from_lru_data[1];
                    write_to_lru_data[2] = 1'b1;
                    if(ufp_rmask_reg != '0) begin
                        ufp_rdata = datas[3];
                    end
                end
                default: begin
                    casez(read_from_lru_data)
                        3'b0?0: begin
                            way_to_write_to_post_miss = 2'd3;
                            dirty_miss = dirties[3] && valid_bit[3];
                            dirty_miss_data_to_write = datas[3];
                            dirty_miss_tag_to_write_to = tags[3];
                        end
                        3'b1?0: begin
                            way_to_write_to_post_miss = 2'd2;
                            dirty_miss = dirties[2] && valid_bit[2];
                            dirty_miss_data_to_write = datas[2];
                            dirty_miss_tag_to_write_to = tags[2];
                        end
                        3'b?01: begin
                            way_to_write_to_post_miss = 2'd1;
                            dirty_miss = dirties[1] && valid_bit[1];
                            dirty_miss_data_to_write = datas[1];
                            dirty_miss_tag_to_write_to = tags[1];
                        end
                        3'b?11: begin
                            way_to_write_to_post_miss = 2'd0;
                            dirty_miss = dirties[0] && valid_bit[0];
                            dirty_miss_data_to_write = datas[0];
                            dirty_miss_tag_to_write_to = tags[0];
                        end
                        default: begin
                            way_to_write_to_post_miss = 2'bxx;
                            dirty_miss = 1'bx;
                        end
                    endcase
                    clean_miss = !dirty_miss;
                end
            endcase
        end
        dfp_read = 1'b0;
        dfp_write = 1'b0;
        dfp_addr = 'x;
        dfp_wdata = 'x;
        if((clean_miss || clean_miss_waiting_for_resp) && !clean_miss_resp_received) begin
            dfp_read = 1'b1;
            dfp_addr = {ufp_addr_reg[31:5], 5'b00000};
        end else if(dirty_miss && !dirty_miss_resp_received) begin
            dfp_write = 1'b1;
            dfp_addr = {dirty_miss_tag_to_write_to, ufp_addr_set_index_reg, 5'b00000};
            dfp_wdata = dirty_miss_data_to_write;
        end else if(dirty_miss_waiting_for_resp && !dirty_miss_resp_received) begin
            dfp_write = 1'b1;
            dfp_addr = {dirty_miss_tag_to_write_to_reg, ufp_addr_set_index_reg, 5'b00000};
            dfp_wdata = dirty_miss_data_to_write_reg;
        end       
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            ufp_rmask_reg <= '0;
            ufp_wmask_reg <= '0;
            clean_miss_waiting_for_resp <= 1'b0;
            post_clean_miss <= 1'b0;
            dirty_miss_data_to_write_reg <= 'x;
            dirty_miss_tag_to_write_to_reg <= 'x;
            dirty_miss_waiting_for_resp <= 1'b0;
            post_write_hit_stall_reg <= 1'b0;
            write_hit_stall_reg <= 1'b0;
        end else if(dirty_miss) begin
            dirty_miss_waiting_for_resp <= 1'b1;
            way_to_write_to_post_miss_reg <= way_to_write_to_post_miss;
            dirty_miss_data_to_write_reg <= dirty_miss_data_to_write;
            dirty_miss_tag_to_write_to_reg <= dirty_miss_tag_to_write_to;
            write_hit_stall_reg <= 1'b0;
        end else if(dirty_miss_resp_received) begin
            dirty_miss_waiting_for_resp <= 1'b0;
            clean_miss_waiting_for_resp <= 1'b1;
        end else if(clean_miss) begin
            clean_miss_waiting_for_resp <= 1'b1;
            way_to_write_to_post_miss_reg <= way_to_write_to_post_miss;
            write_hit_stall_reg <= 1'b0;
        end else if(clean_miss_resp_received) begin
            clean_miss_waiting_for_resp <= 1'b0;
            post_clean_miss <= 1'b1;
        end else if(post_clean_miss) begin
            post_clean_miss <= 1'b0;
            if(ufp_wmask_reg != '0) begin
                write_hit_stall_reg <= 1'b1;
            end
        end else if(post_write_hit_stall_reg) begin
            post_write_hit_stall_reg <= 1'b0;
            if((ufp_wmask_reg != '0) && !write_hit_stall_reg) begin
                write_hit_stall_reg <= 1'b1;
            end else begin
                write_hit_stall_reg <= 1'b0;
            end
        end else if(clean_miss_waiting_for_resp || dirty_miss_waiting_for_resp) begin
            write_hit_stall_reg <= 1'b0;
        end else begin
            ufp_addr_reg <= ufp_addr;
            ufp_rmask_reg <= ufp_rmask;
            ufp_wmask_reg <= ufp_wmask;
            ufp_wdata_reg <= ufp_wdata;
            if(ufp_wmask != '0 && !write_hit_stall_reg) begin
                write_hit_stall_reg <= 1'b1;
            end else begin
                write_hit_stall_reg <= 1'b0;
            end
            if(actual_write_hit) begin
                post_write_hit_stall_reg <= 1'b1;
            end 
        end
    end
     
    logic [2:0] ignore_dout1;

    lru_array lru_array (
        .clk0       (clk),
        .rst0       (rst),
        .csb0       (1'b0),
        .web0       (1'b1),
        .addr0      (general_array_addr0),
        .din0       ('x),
        .dout0      (read_from_lru_data),
        .csb1       (1'b0),
        .web1       (write_to_lru),
        .addr1      (write_to_lru_addr),
        .din1       (write_to_lru_data),
        .dout1      (ignore_dout1)
    );

endmodule
