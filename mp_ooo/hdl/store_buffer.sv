module store_buffer
import rv32i_types::*;
#(
    parameter                   ROB_DEPTH_BITS = 4,
    parameter                   LSQ_DEPTH_BITS = 3,
    // parameter                   DEPTH_N = 2 ** DEPTH_BITS,
    parameter                   NSIZE = 1,
    localparam                  NSIZE_BITS = $clog2(NSIZE),
    parameter                   CDB_COUNT  = 1,

    parameter                   DEPTH = 2,                  // length of store buffer
    localparam                  DEPTH_BITS = $clog2(DEPTH)
)(
    input   rst,
    input   clk,
    
    input   rob_flush,
    
    // load store queue ports
    output  logic   [NSIZE-1:0]         lsq_dequeue,
    input   lsq_entry_t                 lsq_dout[NSIZE],
    input   logic   [LSQ_DEPTH_BITS:0]      lsq_elemcount,
    
    // dcache ports
    output   logic   [31:0]  data_ufp_addr,
    output   logic   [3:0]   data_ufp_rmask,
    output   logic   [3:0]   data_ufp_wmask,
    input    logic   [31:0]  data_ufp_rdata,
    output   logic   [31:0]  data_ufp_wdata,
    input    logic           data_ufp_resp,
    
    // CDB ports
    input   logic                       cdb_busy,
    output  cdb_t                       cdb,
    
    // ROB ports
    input  logic   [ROB_DEPTH_BITS:0]   rob_elemcount,
    input  logic unsigned [ROB_DEPTH_BITS-1:0] rob_current_tail_addr,
    
    // Commit logic ports
    output logic                        store_done,
    output logic [31:0]                 store_monitor_mem_wdata,
    output logic [3:0]                  store_monitor_mem_wmask,
    output logic [31:0]                 store_monitor_mem_addr,
    output logic [31:0]                 store_monitor_rs1_rdata,
    output logic [31:0]                 store_monitor_rs2_rdata
);
    // store queue signals
    logic                               sq_enq, sq_deq;
    sb_entry_t                          sq_din[1];
    sb_entry_t                          sq_dout[1];
    logic [DEPTH_BITS:0]                sq_freespace;
    logic [DEPTH_BITS:0]                sq_elemcount;
    sb_entry_t                          sq_mem[DEPTH];
    logic unsigned  [DEPTH_BITS-1:0]    sq_head_addr;
    
    // store queue
    n_store_queue #(
        .DEPTH_BITS(DEPTH_BITS), // depth = 2 ** depth_index
        .NSIZE(1)
    ) store_q (
        .clk,
        .rst,
        .din    (sq_din ),
        .enqueue(sq_enq ),
        .dequeue(sq_deq ),
        .dout   (sq_dout),
        .freespace(sq_freespace),
        .elemcount(sq_elemcount),
        .Qmem   (sq_mem ),   // expose queue contents to check for loads
        .head_addr(sq_head_addr)
    );

    // for branches. invalidate next dcache response in case we request it before rob_flush comes
    logic invalidate_resp;

    always_ff @(posedge clk) begin
        if(rst) begin
            invalidate_resp <= '0;
        end else if(rob_flush) begin
            invalidate_resp <= '1;
        end else if(data_ufp_resp) begin
            invalidate_resp <= '0;
        end
    end

    logic condition;
    logic condition_1;
    assign condition = lsq_dout[0].ready && lsq_elemcount != '0 && rob_elemcount != '0;
    assign condition_1 = lsq_dout[1].ready && lsq_elemcount > (LSQ_DEPTH_BITS + 1)'(1) && rob_elemcount != '0;

    logic forwardable; // 1 if lsq_dout contains matching addresses with those in the store queue
    logic [3:0] curr_match_mask; // currently matching mask according to queue index
    logic [3:0] match_mask; // total byte mask of matching bytes
    logic [31:0] load_sq_rdata; // reconstructed rdata from store queue
    logic [DEPTH_BITS-1:0] queue_idx; // for loop index, but ordered such that 0=tail_addr

    always_comb begin
        forwardable = '0;
        curr_match_mask = '0;
        match_mask = '0;
        load_sq_rdata = 'x;

        for (int i = 0; i < DEPTH; i++) begin
            queue_idx = unsigned'(unsigned'(DEPTH_BITS'(i))+sq_head_addr);
            // check valid and matching address
            if (sq_mem[queue_idx].addr[31:2] == lsq_dout[0].addr[31:2]) begin
                // check lsq_dout mask with Qmem mask
                curr_match_mask = lsq_dout[0].mask & sq_mem[queue_idx].wmask;
                match_mask |= curr_match_mask;
                // build load rdata from data in store queue according to the current matching bytes
                for (int byte_idx = 0; byte_idx < 4; byte_idx++) begin
                    if (curr_match_mask[byte_idx]) begin
                        load_sq_rdata[8*byte_idx +: 8] = sq_mem[queue_idx].wdata[8*byte_idx +: 8];
                    end
                end
            end
        end
        // check matching byte mask against desired rmask
        if (match_mask == lsq_dout[0].mask) begin
            forwardable = '1;
        end
    end

    logic cache_load; // flag to indicate if the current cache operation is a load
    logic cache_store;

    logic cache_load_next; // indicate if we need to load to cache next
    logic cache_load_next_1;
    logic cache_store_next;
    // TODO this condition is ugly so I can consider for loads when the cache is busy and not busy...
    assign cache_load_next = (((!data_ufp_resp || invalidate_resp) && !cache_store) || (data_ufp_resp && cache_store)) && lsq_dout[0].is_load && !forwardable && condition;
    assign cache_load_next_1 = data_ufp_resp && !invalidate_resp && cache_load && lsq_dout[1].is_load && condition_1;

    always_ff @ (posedge clk) begin
        if (rst) begin
            cache_load <= '0;
            cache_store <= '0;
        end else begin
            if (cache_load_next || cache_load_next_1) begin
                cache_load <= '1;
                cache_store <= '0;
            end else if(cache_store_next) begin
                cache_load <= '0;
                cache_store <= '1;
            end else if (data_ufp_resp) begin
                cache_load <= '0;
                cache_store <= '0;
            end
        end
    end

    logic [31:0] saved_load_sq_rdata; // save the data since this is combinational as well.
    always_ff @(posedge clk) begin
        if (rst) begin
            saved_load_sq_rdata <= 'x;
        end else if (data_ufp_resp) begin
            saved_load_sq_rdata <= load_sq_rdata;
        end
    end

    logic [31:0] load_data; // data used for final load calculation
    always_comb begin
        if(cdb_busy) begin end // CDB will never be busy
        load_data = 'x;
        sq_enq = '0;
        sq_deq = (sq_elemcount != '0) && (data_ufp_resp && !invalidate_resp) && !cache_load;
        
        // data cache
        data_ufp_addr   = 'x; // dependent on store or load
        data_ufp_rmask  = '0;
        data_ufp_wmask  = '0;
        data_ufp_wdata  = 'x;
        
        cache_store_next = '0;

        if (cache_load_next) begin
            data_ufp_addr   = {lsq_dout[0].addr[31:2], 2'b00};
            data_ufp_rmask  = lsq_dout[0].mask & {4{lsq_dout[0].ready}};
            data_ufp_wmask  = '0;
            data_ufp_wdata  = 'x;
        end else if(cache_load_next_1) begin
            data_ufp_addr   = {lsq_dout[1].addr[31:2], 2'b00};
            data_ufp_rmask  = lsq_dout[1].mask & {4{lsq_dout[1].ready}};
            data_ufp_wmask  = '0;
            data_ufp_wdata  = 'x;
        end else if((!data_ufp_resp || invalidate_resp) && sq_elemcount != '0 && !sq_deq) begin
            cache_store_next = 1'b1;
            data_ufp_addr   = sq_dout[0].addr;
            data_ufp_rmask  = '0;
            data_ufp_wmask  = sq_dout[0].wmask;
            data_ufp_wdata  = sq_dout[0].wdata;
        end

        sq_din[0].wmask = '0;
        sq_din[0].addr  = 'x;
        sq_din[0].wdata = 'x;
        lsq_dequeue = '0;

        // stores
        if(!lsq_dout[0].is_load && condition) begin
            if(rob_current_tail_addr == lsq_dout[0].rob_id && sq_freespace != '0) begin // Store cant happen until it is at the head of the ROB
                sq_din[0].wmask = lsq_dout[0].mask;
                sq_din[0].addr = {lsq_dout[0].addr[31:2], 2'b00};
                sq_din[0].wdata = lsq_dout[0].wdata;
                sq_enq = '1;
                lsq_dequeue[0] = '1;
            end
        end

        cdb.ready = '0;
        cdb.rob_id = 'x;
        cdb.ar_dest = 'x;
        cdb.pr_dest = 'x;
        cdb.result = 'x;
        cdb.monitor_rs1_rdata = 'x;
        cdb.monitor_rs2_rdata = 'x;
        cdb.monitor_mem_rdata = 'x;
        cdb.monitor_mem_rmask = '0;
        cdb.monitor_mem_addr  = 'x;
        // TODO
        // how does this interact with lsq_dequeues from the store condition above?
        // 
        if (lsq_dout[0].is_load && condition) begin
            if ((cache_load && data_ufp_resp && !invalidate_resp) || forwardable) begin
                lsq_dequeue[0] = '1;
            end
        end

        // swap load data depending on if we can forward or not
        if (lsq_dout[0].is_load && condition && forwardable) begin
            load_data = load_sq_rdata;
            cdb.ready = '1;
        end else if (cache_load) begin
            load_data = data_ufp_rdata;
            if (data_ufp_resp && !invalidate_resp) begin
                cdb.ready = '1;
            end else begin
                cdb.ready = '0;
            end
            
            // forward bytes that match. use dcache bytes if there is no match.
            for (int byte_idx = 0; byte_idx < 4; byte_idx++) begin
                if (match_mask[byte_idx]) begin
                    load_data[8*byte_idx +: 8] = load_sq_rdata[8*byte_idx +: 8];
                end
            end
        end

        // loads
        // if(lsq_dout[0].is_load && condition) begin
        //     if (forwardable) begin
        //         // wait for cdb to finish whatever its doing
        //         // if (cdb_busy) begin
        //         //     // cdb.ready = '0;
        //         //     lsq_dequeue[0] = '0;
        //         // end else begin // once cdb is not busy, broadcast and dequeue from LSQ
        //         //     // cdb.ready = '1;
        //         //     lsq_dequeue[0] = '1;
        //         // end
        //     end else begin
        //         // if (cdb_busy) begin
        //         //     lsq_dequeue[0] = '0;
        //         // end else begin 
        //         //     lsq_dequeue[0] = '1;
        //         // end
        //     end
        // end
        // final cdb broadcast
        cdb.rob_id  = lsq_dout[0].rob_id;
        cdb.ar_dest = lsq_dout[0].ar_dest;
        cdb.pr_dest = lsq_dout[0].pr_dest;
        unique case  (lsq_dout[0].funct3)
            load_f3_lb : cdb.result = {{24{load_data[7 +8 *lsq_dout[0].addr[1:0]]}}, load_data[8 *lsq_dout[0].addr[1:0] +: 8 ]};
            load_f3_lbu: cdb.result = {{24{1'b0}}                                  , load_data[8 *lsq_dout[0].addr[1:0] +: 8 ]};
            load_f3_lh : cdb.result = {{16{load_data[15+16*lsq_dout[0].addr[1]  ]}}, load_data[16*lsq_dout[0].addr[1]   +: 16]};
            load_f3_lhu: cdb.result = {{16{1'b0}}                                  , load_data[16*lsq_dout[0].addr[1]   +: 16]};
            load_f3_lw : cdb.result = load_data;
            default    : cdb.result = 'x;
        endcase
        cdb.monitor_rs1_rdata = lsq_dout[0].monitor_rs1_rdata;
        cdb.monitor_rs2_rdata = lsq_dout[0].monitor_rs2_rdata;
        cdb.monitor_mem_rdata = load_data;
        cdb.monitor_mem_rmask = lsq_dout[0].mask;
        cdb.monitor_mem_addr  = {lsq_dout[0].addr[31:2], 2'b00};


        store_done = '0;
        store_monitor_mem_wdata = 'x;
        store_monitor_mem_wmask = '0;
        store_monitor_mem_addr = 'x;
        store_monitor_rs1_rdata = 'x;
        store_monitor_rs2_rdata = 'x;
        // stores
        if(sq_enq) begin
            store_done = '1;
            store_monitor_mem_wdata = lsq_dout[0].wdata;
            store_monitor_mem_wmask = lsq_dout[0].mask;
            store_monitor_mem_addr  = {lsq_dout[0].addr[31:2], 2'b00};
            store_monitor_rs1_rdata = lsq_dout[0].monitor_rs1_rdata;
            store_monitor_rs2_rdata = lsq_dout[0].monitor_rs2_rdata;
        end

    end




    

    // always_comb begin
    //     // Data Cache logic
    //     data_ufp_addr = 'x;
    //     data_ufp_rmask = '0;
    //     data_ufp_wmask = '0;
    //     data_ufp_wdata = 'x;
    //     if((!data_ufp_resp || invalidate_resp) && lsq_elemcount != '0 && rob_elemcount != '0 && lsq_dout[0].ready) begin
    //         if(lsq_dout[0].is_load) begin
    //             data_ufp_addr = {lsq_dout[0].addr[31:2], 2'b00};
    //             data_ufp_rmask = lsq_dout[0].mask;
    //         end else if(rob_current_tail_addr == lsq_dout[0].rob_id) begin // Store cant happen until it is at the head of the ROB
    //             data_ufp_addr = {lsq_dout[0].addr[31:2], 2'b00};
    //             data_ufp_wmask = lsq_dout[0].mask;
    //             data_ufp_wdata = lsq_dout[0].wdata;
    //         end
    //     end
        
    //     cdb.ready = '0;
    //     cdb.rob_id = 'x;
    //     cdb.ar_dest = 'x;
    //     cdb.pr_dest = 'x;
    //     cdb.result = 'x;
    //     cdb.monitor_rs1_rdata = 'x;
    //     cdb.monitor_rs2_rdata = 'x;
    //     cdb.monitor_mem_rdata = 'x;
    //     cdb.monitor_mem_rmask = '0;
    //     cdb.monitor_mem_addr  = 'x;
    //     lsq_dequeue = '0;
    //     if(data_ufp_resp && !invalidate_resp && lsq_dout[0].is_load && lsq_dout[0].ready && lsq_elemcount != '0 && rob_elemcount != '0) begin
    //         if(cdb_busy) begin // Keep reading from the cache until it isnt busy (if its already in cache, future reads will only take a cycle)
    //             data_ufp_addr = {lsq_dout[0].addr[31:2], 2'b00};
    //             data_ufp_rmask = '1;
    //         end else begin
    //             cdb.ready = '1;
    //             cdb.rob_id = lsq_dout[0].rob_id;
    //             cdb.ar_dest = lsq_dout[0].ar_dest;
    //             cdb.pr_dest = lsq_dout[0].pr_dest;
    //             unique case (lsq_dout[0].funct3)
    //                 load_f3_lb : cdb.result = {{24{data_ufp_rdata[7 +8 *lsq_dout[0].addr[1:0]]}}, data_ufp_rdata[8 *lsq_dout[0].addr[1:0] +: 8 ]};
    //                 load_f3_lbu: cdb.result = {{24{1'b0}}                                      , data_ufp_rdata[8 *lsq_dout[0].addr[1:0] +: 8 ]};
    //                 load_f3_lh : cdb.result = {{16{data_ufp_rdata[15+16*lsq_dout[0].addr[1]  ]}}, data_ufp_rdata[16*lsq_dout[0].addr[1]   +: 16]};
    //                 load_f3_lhu: cdb.result = {{16{1'b0}}                                      , data_ufp_rdata[16*lsq_dout[0].addr[1]   +: 16]};
    //                 load_f3_lw : cdb.result = data_ufp_rdata;
    //                 default    : cdb.result = 'x;
    //             endcase
    //             cdb.monitor_rs1_rdata = lsq_dout[0].monitor_rs1_rdata;
    //             cdb.monitor_rs2_rdata = lsq_dout[0].monitor_rs2_rdata;
    //             cdb.monitor_mem_rdata = data_ufp_rdata;
    //             cdb.monitor_mem_rmask = lsq_dout[0].mask;
    //             cdb.monitor_mem_addr  = {lsq_dout[0].addr[31:2], 2'b00};
    //             lsq_dequeue[0] = '1;
    //         end
    //     end
        
    //     store_done = '0;
    //     store_monitor_mem_wdata = 'x;
    //     store_monitor_mem_wmask = '0;
    //     store_monitor_mem_addr = 'x;
    //     store_monitor_rs1_rdata = 'x;
    //     store_monitor_rs2_rdata = 'x;
        
    //     if(data_ufp_resp && !invalidate_resp && !lsq_dout[0].is_load && lsq_dout[0].ready && lsq_elemcount != '0 && rob_elemcount != '0) begin
    //         store_done = '1;
    //         store_monitor_mem_wdata = lsq_dout[0].wdata;
    //         store_monitor_mem_wmask = lsq_dout[0].mask;
    //         store_monitor_mem_addr  = {lsq_dout[0].addr[31:2], 2'b00};
    //         store_monitor_rs1_rdata = lsq_dout[0].monitor_rs1_rdata;
    //         store_monitor_rs2_rdata = lsq_dout[0].monitor_rs2_rdata;
    //         lsq_dequeue[0] = '1;
    //     end
    // end


    // always_comb begin

    // end

endmodule : store_buffer
