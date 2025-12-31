typedef enum logic [3:0] { // {dirty=1, hit=1, write, read}
    read_hit            = 4'b0101,
    read_hit_d          = 4'b1101,
    read_clean_miss     = 4'b0001,
    read_dirty_miss     = 4'b1001,
    write_hit           = 4'b0110,
    write_hit_d         = 4'b1110,
    write_clean_miss    = 4'b0010,
    write_dirty_miss    = 4'b1010,
    idle                = 4'b0000
} operation_t;

typedef struct packed { // save these values for the next stage
    logic   [31:0]  ufp_addr;
    logic   [3:0]   ufp_rmask;
    logic   [3:0]   ufp_wmask;
    logic   [31:0]  ufp_wdata;
    logic           ufp_read;
    logic           ufp_write;
    logic           valid; // ufp_read | ufp_write
} stage_reg_t;

module cache (
    input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    output  logic   [31:0]  ufp_rdata,
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
            // alias from ufp_addr and stage_reg.ufp_addr
            logic   [22:0]  ufp_tag;
            logic   [3:0]   ufp_set_idx;
            logic   [4:0]   ufp_offset;
            logic   [22:0]  stage_ufp_tag;
            logic   [3:0]   stage_ufp_set_idx;
            logic   [4:0]   stage_ufp_offset;
            // signals to indicate ufp read/writes
            logic           ufp_read;
            logic           ufp_write;

            // alias for arrays
            logic   [3:0]   set_idx;
            // arrays per way
            // chip selects and writes (parallel access data,tag,valid,dirty)
            logic           chip_sels[4]; // chip selects (active low)
            logic           write_ens[4]; // read/write. (write=1, read=0)
            // data array
            logic   [31:0]  data_wmask;
            logic   [255:0] data_in;
            logic   [255:0] data_outs[4];
            // tag array
            logic   [22:0]  tag_in;
            logic   [22:0]  tag_outs[4];
            logic           dirty_in;
            logic           dirty_outs[4];
            // valid/dirty array
            logic           valid_in;
            logic           valid_outs[4];
            // hits array
            logic           hits[4];

            // unified signals chosen by which way was a hit
            logic   [255:0] data_out;
            logic   [22:0]  tag_out;
            logic           dirty_out;
            logic           hit;
            logic   [1:0]   hit_way;
            logic   [1:0]   evicted_way;

            // stall signal to indicate when we are accepting ufp requests
            // logic           stall_request; // write hit stall
            // logic           stall_stage;
            // stage register
            logic           load_stage;
            // logic           saved; // flag to indicate if we saved from write hit stall
            stage_reg_t     saved_reg;
            stage_reg_t     stage_reg;
            // counter
            logic   [2:0]   count;
            // flag to indicate last operation was a write hit
            // logic           prev_write_hit;
            operation_t     op;
            operation_t     op_saved;
            logic           op_saved_flag;
            // plru
            logic           plru_rcs, plru_wcs;
            logic   [3:0]   plru_raddr, plru_waddr;
            logic   [2:0]   plru_rout, plru_win;
    
    
    // 4 ways
    generate for (genvar i = 0; i < 4; i++) begin : arrays
        mp_cache_data_array data_array (
            .clk0       (clk),                              // input    clk
            .csb0       (chip_sels[i]),                     // input    chip select (active low)
            .web0       (write_ens[i]),                     // input    write enable (write=1, read=0)
            .wmask0     (data_wmask),                       // input    write mask [31:0]
            .addr0      (set_idx),                          // input    address [3:0] (set idx)
            .din0       (data_in),                          // input    data [255:0]
            .dout0      (data_outs[i])                      // output   data [255:0]
        );
        mp_cache_tag_array tag_array (
            .clk0       (clk),                              // input    clk
            .csb0       (chip_sels[i]),                     // input    chip select (active low)
            .web0       (write_ens[i]),                     // input    write enable (write=1, read=0)
            .addr0      (set_idx),                          // input    address [3:0] (set idx)
            .din0       ({     dirty_in,      tag_in}),     // input    data [23:0]
            .dout0      ({dirty_outs[i], tag_outs[i]})      // output   data [23:0]
        );
        valid_array valid_array (
            .clk0       (clk),                              // input    clk
            .rst0       (rst),                              // input    rst
            .csb0       (chip_sels[i]),                     // input    chip select (active low)
            .web0       (write_ens[i]),                     // input    write enable (write=1, read=0)
            .addr0      (set_idx),                          // input    address [3:0] (set idx)
            .din0       (valid_in),                         // input    data
            .dout0      (valid_outs[i])                     // output   data
        );
    end endgenerate

    lru_array lru_array (
        .clk0       (clk),
        .rst0       (rst),
        .csb0       (plru_rcs),
        .web0       ('1), // read
        .addr0      (plru_raddr),
        .din0       ('x),
        .dout0      (plru_rout),
        .csb1       (plru_wcs),
        .web1       ('0), // write
        .addr1      (plru_waddr),
        .din1       (plru_win),
        .dout1      ()
    );

    // PLRU stuff
    always_comb begin
        // failure case
        evicted_way = 'x;
        plru_win = 'x;
        
        // plru
        plru_rcs = ~load_stage; // read when loading
        plru_wcs = ~ufp_resp; // write when complete
        plru_raddr = set_idx;
        plru_waddr = stage_ufp_set_idx;

        // search for the LRU by going the opposite branch of the MRU
        if (plru_rout[0]) begin // MRU was right, go left
            if (plru_rout[1]) begin // MRU was right, go left
                evicted_way = 2'd0;
            end else begin // MRU was left, go right
                evicted_way = 2'd1;
            end
        end else begin // MRU was left, go right
            if (plru_rout[2]) begin // MRU was right, go left
                evicted_way = 2'd2;
            end else begin // MRU was left, go right
                evicted_way = 2'd3;
            end
        end

        unique case (hit_way)
            2'd0: begin
                plru_win = {plru_rout[2], 1'b0, 1'b0};
            end
            2'd1: begin
                plru_win = {plru_rout[2], 1'b1, 1'b0};
            end
            2'd2: begin
                plru_win = {1'b0, plru_rout[1], 1'b1};
            end
            2'd3: begin
                plru_win = {1'b1, plru_rout[1], 1'b1};
            end
        endcase
    end

    // ufp alias
    assign ufp_tag      = ufp_addr[31:9];
    assign ufp_set_idx  = ufp_addr[8:5];
    assign ufp_offset   = ufp_addr[4:0];
    assign stage_ufp_tag     = stage_reg.ufp_addr[31:9];
    assign stage_ufp_set_idx = stage_reg.ufp_addr[8:5];
    assign stage_ufp_offset  = stage_reg.ufp_addr[4:0];

    assign ufp_read  = ufp_rmask[3] | ufp_rmask[2] | ufp_rmask[1] | ufp_rmask[0];
    assign ufp_write = ufp_wmask[3] | ufp_wmask[2] | ufp_wmask[1] | ufp_wmask[0];

    assign op = (~op_saved_flag) ? operation_t'({dirty_out, hit, stage_reg.ufp_write, stage_reg.ufp_read}) : op_saved;
    
    always_ff @ (posedge clk) begin
        if (rst) begin
            op_saved      <= idle;
            op_saved_flag <= 1'b1;
        end else if (load_stage) begin
            op_saved      <= idle;
            op_saved_flag <= 1'b0;
        end else if (~op_saved_flag) begin
            op_saved      <= operation_t'({dirty_out, hit, stage_reg.ufp_write, stage_reg.ufp_read});
            op_saved_flag <= 1'b1;
        end
    end


    // stage register
    always_ff @ (posedge clk) begin
        if (rst) begin // reset
            stage_reg.ufp_addr  <= 'x;
            stage_reg.ufp_rmask <= 'x;
            stage_reg.ufp_wmask <= 'x;
            stage_reg.ufp_wdata <= 'x;
            stage_reg.ufp_read  <= 'x;
            stage_reg.ufp_write <= 'x;
            stage_reg.valid     <= 1'b0;
            saved_reg.ufp_addr  <= 'x;
            saved_reg.ufp_rmask <= 'x;
            saved_reg.ufp_wmask <= 'x;
            saved_reg.ufp_wdata <= 'x;
            saved_reg.ufp_read  <= 'x;
            saved_reg.ufp_write <= 'x;
            saved_reg.valid     <= 1'b0;
        end else if (load_stage) begin // save the current request in our stage register
            // if (saved_reg.ufp_read | saved_reg.ufp_write) begin
            if (saved_reg.valid) begin
                stage_reg.ufp_addr  <= saved_reg.ufp_addr;
                stage_reg.ufp_rmask <= saved_reg.ufp_rmask;
                stage_reg.ufp_wmask <= saved_reg.ufp_wmask;
                stage_reg.ufp_wdata <= saved_reg.ufp_wdata;
                stage_reg.ufp_read  <= saved_reg.ufp_read;
                stage_reg.ufp_write <= saved_reg.ufp_write;
                stage_reg.valid     <= saved_reg.valid;
                // stage_reg.valid     <= saved_reg.ufp_read | saved_reg.ufp_write;
            end else begin
                stage_reg.ufp_addr  <= ufp_addr;
                stage_reg.ufp_rmask <= ufp_rmask;
                stage_reg.ufp_wmask <= ufp_wmask;
                stage_reg.ufp_wdata <= ufp_wdata;
                stage_reg.ufp_read  <= ufp_read;
                stage_reg.ufp_write <= ufp_write;
                stage_reg.valid     <= ufp_read | ufp_write;
            end
            // saved_reg.ufp_addr  <= 'x;
            // saved_reg.ufp_rmask <= 'x;
            // saved_reg.ufp_wmask <= 'x;
            // saved_reg.ufp_wdata <= 'x;
            // saved_reg.ufp_read  <= 'x;
            // saved_reg.ufp_write <= 'x;
            saved_reg.valid     <= 1'b0;
        end else if (stage_reg.ufp_write) begin // stalled, so save the request now
            saved_reg.ufp_addr  <= ufp_addr;
            saved_reg.ufp_rmask <= ufp_rmask;
            saved_reg.ufp_wmask <= ufp_wmask;
            saved_reg.ufp_wdata <= ufp_wdata;
            saved_reg.ufp_read  <= ufp_read;
            saved_reg.ufp_write <= ufp_write;
            saved_reg.valid     <= ufp_read | ufp_write;
        end

    end



    // hit logic
    always_comb begin
        data_out    = 'x;
        tag_out     = 'x;
        dirty_out   = valid_outs[evicted_way] & dirty_outs[evicted_way];
        hit_way     = 'x;

        for (int i = 0; i < 4; i++) begin
            hits[i] = (stage_ufp_tag == tag_outs[i]) & valid_outs[i];
            if (hits[i]) begin // hit!
                data_out    = data_outs[i];
                tag_out     = tag_outs[i];
                dirty_out   = dirty_outs[i];
            end
        end
        // unify hits (assuming only one way is hit at once!)
        hit = hits[3] | hits[2] | hits[1] | hits[0];

        if (hits[0]) begin
            hit_way = 2'd0;
        end
        if (hits[1]) begin
            hit_way = 2'd1;
        end
        if (hits[2]) begin
            hit_way = 2'd2;
        end
        if (hits[3]) begin
            hit_way = 2'd3;
        end
    end

    always_comb begin
        load_stage = 1'b1; // always load.

        // idle behavior
        // ufp outputs
        ufp_rdata   = 'x;
        ufp_resp    = '0;
        // dfp outputs
        dfp_read    = 1'b0;
        dfp_write   = 1'b0;
        dfp_addr    = 'x;
        dfp_wdata   = 'x;

        unique case (op) // use values derived from SRAM
            read_hit, read_hit_d: begin
                unique case (count)
                    3'd0: begin
                        ufp_resp    = 1'b1;
                        ufp_rdata   = data_out[8*stage_ufp_offset +: 32];
                    end
                    3'd1: begin
                        // do nothing
                    end
                    default: begin
                        // should never get here
                    end
                endcase
            end
            write_hit, write_hit_d: begin
                unique case (count)
                    3'd0: begin
                        ufp_resp    = 1'b1;
                        load_stage = 1'b0;
                    end
                    3'd1: begin // stalls
                    end
                    default: begin
                        // should never get here
                    end
                endcase
            end      
            read_clean_miss: begin
                unique case (count)
                    3'd0: begin
                        dfp_read    = 1'b1;
                        dfp_addr    = {stage_reg.ufp_addr[31:5], 5'b00000};
                        load_stage = 1'b0;
                    end
                    3'd1: begin
                        load_stage = 1'b0;
                    end
                    3'd2: begin
                        ufp_resp    = 1'b1;
                        ufp_rdata   = data_outs[evicted_way][8*stage_ufp_offset +: 32]; // maybe
                        load_stage  = 1'b1;
                    end
                    default: begin
                        // should never get here
                    end
                endcase
            end
            write_clean_miss: begin
                unique case (count)
                    3'd0: begin
                        dfp_read    = 1'b1;
                        dfp_addr    = {stage_reg.ufp_addr[31:5], 5'b00000};
                        load_stage = 1'b0;
                    end
                    3'd1: begin
                        load_stage = 1'b0;
                    end
                    3'd2: begin
                        ufp_resp   = 1'b1;
                        load_stage = 1'b0; //stall
                    end
                    3'd3: begin
                        load_stage = 1'b1; //stall
                        // should never get here
                    end
                    default: begin

                    end
                endcase
            end
            read_dirty_miss: begin
                unique case (count)
                    3'd0: begin
                        dfp_write   = 1'b1;
                        dfp_addr    = {tag_outs[evicted_way], stage_ufp_set_idx, 5'h00};
                        dfp_wdata   = data_outs[evicted_way];
                        load_stage  = 1'b0;

                    end
                    3'd1: begin
                        dfp_read    = 1'b1;
                        dfp_addr    = {stage_reg.ufp_addr[31:5], 5'b00000};
                        load_stage = 1'b0;
                    end
                    3'd2: begin
                        load_stage = 1'b0;
                    end
                    3'd3: begin
                        ufp_resp   = 1'b1;
                        ufp_rdata  = data_outs[evicted_way][8*stage_ufp_offset +: 32]; // maybe
                        
                        // should never get here
                    end
                    default: begin

                    end
                endcase
            end
            write_dirty_miss: begin
                unique case (count)
                    3'd0: begin
                        dfp_write   = 1'b1;
                        dfp_addr    = {tag_outs[evicted_way], stage_ufp_set_idx, 5'h00};
                        dfp_wdata   = data_outs[evicted_way];
                        load_stage  = 1'b0;
                    end
                    3'd1: begin
                        dfp_read    = 1'b1;
                        dfp_addr    = {stage_reg.ufp_addr[31:5], 5'b00000};
                        load_stage = 1'b0;
                    end
                    3'd2: begin
                        load_stage = 1'b0;
                    end
                    3'd3: begin
                        ufp_resp   = 1'b1;
                        load_stage = 1'b0;
                    end
                    3'd4: begin
                        load_stage = 1'b1;
                    end
                    default: begin

                    end
                endcase
            end
            default: begin
                // empty so we use the idle signals defined above
            end
        endcase
    end

    // set_idx
    always_comb begin
        if (load_stage) begin
            // if (saved_reg.write | saved_reg.read) begin
            if (saved_reg.valid) begin
                set_idx = saved_reg.ufp_addr[8:5];
            end else begin
                set_idx = ufp_set_idx;
            end
        end else begin
            set_idx = stage_ufp_set_idx;
        end
    end

    always_comb begin
        valid_in    = 1'b1;
        dirty_in    = 'x;
        tag_in      = stage_ufp_tag;
        data_in     = 'x;
        data_wmask  = 'x;
        for (int i = 0; i < 4; i++) begin
            chip_sels   [i] = 1'b0;
            write_ens   [i] = 1'b1; // read
            // data_wmasks [i] = 'x;
        end

        unique case (op) // use values derived from SRAM
            read_hit, read_hit_d: begin
                // nothing
            end
            write_hit, write_hit_d: begin
                // data_wmasks [hit_way] = '0;
                // data_wmasks [hit_way][stage_ufp_offset +: 4] = stage_reg.ufp_wmask;
                data_wmask = '0;
                data_wmask[stage_ufp_offset +: 4] = stage_reg.ufp_wmask;
            
                data_in[8*stage_ufp_offset +: 32] = stage_reg.ufp_wdata;
                
                dirty_in = 1'b1;
                unique case (count)
                    3'd0: begin
                        chip_sels[hit_way] = 1'b0;
                        write_ens[hit_way] = 1'b0; // write
                    end
                    default: begin
                    end
                endcase
            end      
            read_clean_miss: begin
                // data_wmasks [evicted_way] = '1;
                data_wmask = '1;
                
                data_in = dfp_rdata;
                dirty_in = 1'b0;
                unique case (count)
                    3'd0: begin
                        if (dfp_resp) begin // write to SRAM
                            chip_sels[evicted_way] = 1'b0;
                            write_ens[evicted_way] = 1'b0; // write
                        end
                    end
                    default: begin
                    end
                endcase
            end
            write_clean_miss: begin
                // data_wmasks [evicted_way] = '1;
                data_wmask = '1;

                data_in = dfp_rdata;
                
                if (stage_reg.ufp_wmask[0]) begin
                    data_in[8*(stage_ufp_offset+0) +: 8] = stage_reg.ufp_wdata[0 +: 8];
                end
                if (stage_reg.ufp_wmask[1]) begin
                    data_in[8*(stage_ufp_offset+1) +: 8] = stage_reg.ufp_wdata[8 +: 8];
                end
                if (stage_reg.ufp_wmask[2]) begin
                    data_in[8*(stage_ufp_offset+2) +: 8] = stage_reg.ufp_wdata[16 +: 8];
                end
                if (stage_reg.ufp_wmask[3]) begin
                    data_in[8*(stage_ufp_offset+3) +: 8] = stage_reg.ufp_wdata[24 +: 8];
                end

                dirty_in = 1'b1;

                unique case (count)
                    3'd0: begin
                        if (dfp_resp) begin // write to SRAM
                            chip_sels[evicted_way] = 1'b0;
                            write_ens[evicted_way] = 1'b0; // write
                        end
                    end
                    default: begin
                    end
                endcase
            end
            read_dirty_miss: begin
                // data_wmasks [evicted_way] = '1;
                data_wmask = '1;

                data_in = dfp_rdata;
                dirty_in = 1'b0;
                unique case (count)
                    3'd1: begin
                        if (dfp_resp) begin // write to SRAM
                            chip_sels   [evicted_way] = 1'b0;
                            write_ens   [evicted_way] = 1'b0; // write
                        end
                    end
                    default: begin

                    end
                endcase
            end
            write_dirty_miss: begin
                // data_wmasks [evicted_way] = '1;
                data_wmask = '1;

                data_in = dfp_rdata;
                if (stage_reg.ufp_wmask[0]) begin
                    data_in[8*(stage_ufp_offset+0) +: 8] = stage_reg.ufp_wdata[0 +: 8];
                end
                if (stage_reg.ufp_wmask[1]) begin
                    data_in[8*(stage_ufp_offset+1) +: 8] = stage_reg.ufp_wdata[8 +: 8];
                end
                if (stage_reg.ufp_wmask[2]) begin
                    data_in[8*(stage_ufp_offset+2) +: 8] = stage_reg.ufp_wdata[16 +: 8];
                end
                if (stage_reg.ufp_wmask[3]) begin
                    data_in[8*(stage_ufp_offset+3) +: 8] = stage_reg.ufp_wdata[24 +: 8];
                end

                tag_in = stage_ufp_tag;
                dirty_in = 1'b1;

                unique case (count)
                    3'd1: begin
                        if (dfp_resp) begin // write to SRAM
                            chip_sels   [evicted_way] = 1'b0;
                            write_ens   [evicted_way] = 1'b0; // write
                        end
                    end
                    default: begin
                    end
                endcase
            end
            default: begin
                // empty so we use the idle signals defined above
            end
        endcase
    end


    // counter and prev_write_hit
    always_ff @ (posedge clk) begin
        if (rst) begin // reset
            count           <= 3'b000;
            // prev_write_hit  <= 1'b0;
        end else if (load_stage) begin // reset for next cache operation
            count           <= 3'b000;
            // prev_write_hit  <= hit & stage_reg.ufp_write; // should be equivalent
        end else begin
            unique case (op) // use values derived from SRAM
                read_hit, read_hit_d, write_hit, write_hit_d: begin
                    unique case (count)
                        3'd0: begin
                            count <= count + 2'd1; // update count immediately so we only output ufp resp once
                        end
                        3'd1: begin // dont stall, so should not get here
                            // do nothing
                        end
                        default: begin
                            // should never get here
                        end
                    endcase
                end
                read_clean_miss, write_clean_miss: begin
                    unique case (count)
                        3'd0: begin
                            if (dfp_resp) begin // requesting read from dfp to replace cache line
                                count <= count + 2'd1;
                            end
                        end
                        3'd1: begin // requesting write to cache line
                            count <= count + 2'd1;
                        end
                        3'd2: begin // dont stall, so should not get here
                            count <= count + 2'd1;
                        end
                        default: begin
                            // should never get here
                        end
                    endcase
                end
                read_dirty_miss, write_dirty_miss: begin
                    unique case (count)
                        3'd0: begin // write evicted line to dfp
                            if (dfp_resp) begin
                                count <= count + 2'd1;
                            end
                        end
                        3'd1: begin // requesting read from dfp to replace cache line
                            if (dfp_resp) begin
                                count <= count + 2'd1;
                            end
                        end
                        3'd2, 3'd3: begin // requesting write to cache line
                            count <= count + 2'd1;
                        end
                        default: begin // dont stall, so should not get here
                            // do nothing
                        end
                    endcase
                end
                default: begin
                    // empty
                end
            endcase
        end
    end

endmodule
