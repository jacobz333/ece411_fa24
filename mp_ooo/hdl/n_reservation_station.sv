module n_reservation_station
import rv32i_types::*;
#(
    parameter   PR_BITS         = 5,
    parameter   DEPTH_BITS      = 2,
    localparam  unsigned DEPTH  = 2 ** DEPTH_BITS,
    localparam  [DEPTH_BITS:0]  DEPTH_SMALL = 2 ** DEPTH_BITS,
    parameter                   NSIZE = 1,
    localparam                  NSIZE_BITS = $clog2(NSIZE),
    parameter   CDB_COUNT       = 1,
    
    parameter   BASE_COUNT      = 1,
    parameter   MUL_COUNT       = 1,
    parameter   DIV_COUNT       = 1,
    parameter   BRANCH_COUNT    = 1,
    parameter   LS_COUNT        = 1,
    
    // ALU modules start index
    localparam  BASE_START      = 0,
    localparam  MUL_START       = BASE_COUNT,
    localparam  DIV_START       = BASE_COUNT + MUL_COUNT,
    localparam  BRANCH_START    = BASE_COUNT + MUL_COUNT + DIV_COUNT,
    localparam  LS_START        = BASE_COUNT + MUL_COUNT + DIV_COUNT + BRANCH_COUNT,
    localparam  OUT_COUNT       = BASE_COUNT + MUL_COUNT + DIV_COUNT + BRANCH_COUNT + LS_COUNT
) (
    input   logic                           clk,
    input   logic                           rst,
    
    // from cdb
    input   cdb_t                           cdb[CDB_COUNT],
    
    // from dispatch
    output  logic       [DEPTH_BITS:0]      rs_freespace,
    input   logic       [NSIZE-1:0]         rs_enqueue,
    input   rs_entry_t                      rs_entry_din[NSIZE],
    
    // read from regfile
    output  logic       [PR_BITS-1:0]       ps1_addr[OUT_COUNT],
    output  logic       [PR_BITS-1:0]       ps2_addr[OUT_COUNT],
    
    // to function unit
    output  logic                           base_rs_entry_valid[BASE_COUNT],
    output  rs_entry_t                      base_rs_entry_dout [BASE_COUNT],
    output  logic                           mul_rs_entry_valid[MUL_COUNT],
    output  rs_entry_t                      mul_rs_entry_dout [MUL_COUNT],
    output  logic                           div_rs_entry_valid[DIV_COUNT],
    output  rs_entry_t                      div_rs_entry_dout [DIV_COUNT],
    output  logic                           branch_rs_entry_valid[BRANCH_COUNT],
    output  rs_entry_t                      branch_rs_entry_dout [BRANCH_COUNT],
    output  logic                           ls_rs_entry_valid[LS_COUNT],
    output  rs_entry_t                      ls_rs_entry_dout [LS_COUNT],
 
    // from function unit
    input   logic                           base_fn_ready[BASE_COUNT],
    input   logic                           mul_fn_ready[MUL_COUNT],
    input   logic                           div_fn_ready[DIV_COUNT],
    input   logic                           branch_fn_ready[BRANCH_COUNT],
    input   logic                           ls_fn_ready[LS_COUNT]
);

    rs_entry_t                      rs_entry_arr[DEPTH];
    logic                           rs_dequeue;
    logic                           rs_arr_inuse[DEPTH];
    logic          [DEPTH_BITS-1:0] free_idx[NSIZE];
    // Might be added as an output if needed
    logic       [DEPTH_BITS:0]      rs_elemcount;
    
    logic          [DEPTH_BITS-1:0] base_out_idx[BASE_COUNT]; 
    logic          [DEPTH_BITS-1:0] mul_out_idx[MUL_COUNT];
    logic          [DEPTH_BITS-1:0] div_out_idx[DIV_COUNT];
    logic          [DEPTH_BITS-1:0] branch_out_idx[BRANCH_COUNT]; 
    logic          [DEPTH_BITS-1:0] ls_out_idx[LS_COUNT]; 
    
    cdb_t                           lagged_cdb[CDB_COUNT];
    
    int counter;
    
    int counterA;
    int counterB;
    int counterC;
    int counterD;
    int counterE;

    always_comb begin
        // Default values for some outputs
        for(int unsigned i = 0; i < OUT_COUNT; i++) begin
            ps1_addr[i] = '0;
            ps2_addr[i] = '0;
        end
        
        for(int unsigned i = 0; i < NSIZE; i++) begin
            free_idx[i] = 'x;
        end
    
        // assign element counts
        rs_elemcount = '0;
        for (int unsigned i = 0; i < DEPTH; i++) begin
            if(rs_arr_inuse[i]) begin
                rs_elemcount = rs_elemcount + (DEPTH_BITS + 1)'(1);
            end
        end
        rs_freespace = DEPTH_SMALL - rs_elemcount;

        // assign free_idx
        counter = 0;
        for(int unsigned i = 0; i < DEPTH; i++) begin
            if(~rs_arr_inuse[i]) begin
                free_idx[counter] = (DEPTH_BITS)'(i);
                counter = counter + 1;
                if(counter == NSIZE)
                    break;
            end
        end
        
        // assign out_idx
        counterA = 0;
        for(int unsigned i = 0; i < BASE_COUNT; i++) begin
            base_rs_entry_valid[i] = '0;
            base_rs_entry_dout[i] = 'x;
            base_out_idx[i] = 'x;
        end
        for(int unsigned i = 0; i < DEPTH; i++) begin
            if(rs_arr_inuse[i] && rs_entry_arr[i].ps1_valid && rs_entry_arr[i].ps2_valid) begin
                if(rs_entry_arr[i].opcode == op_b_lui || rs_entry_arr[i].opcode == op_b_auipc || rs_entry_arr[i].opcode == op_b_imm || (rs_entry_arr[i].opcode == op_b_reg && rs_entry_arr[i].funct7 != mult_div)) begin base_out_idx[counterA] = (DEPTH_BITS)'(i); base_rs_entry_valid[counterA] = '1;
                    base_rs_entry_dout[counterA] = rs_entry_arr[i];
                    ps1_addr[BASE_START + counterA] = rs_entry_arr[i].ps1_addr;
                    ps2_addr[BASE_START + counterA] = rs_entry_arr[i].ps2_addr;
                    counterA = counterA + 1;
                    if(counterA == BASE_COUNT)
                        break;
                end
            end
        end
        
        counterB = 0;
        for(int unsigned i = 0; i < MUL_COUNT; i++) begin
            mul_rs_entry_valid[i] = '0;
            mul_rs_entry_dout[i] = 'x;
            mul_out_idx[i] = 'x;
        end
        for(int unsigned i = 0; i < DEPTH; i++) begin
            if(rs_arr_inuse[i] && rs_entry_arr[i].ps1_valid && rs_entry_arr[i].ps2_valid) begin
                if(rs_entry_arr[i].opcode == op_b_reg && rs_entry_arr[i].funct7 == mult_div && ~rs_entry_arr[i].funct3[2]) begin
                    mul_out_idx[counterB] = (DEPTH_BITS)'(i);
                    mul_rs_entry_valid[counterB] = '1;
                    mul_rs_entry_dout[counterB] = rs_entry_arr[i];
                    ps1_addr[MUL_START + counterB] = rs_entry_arr[i].ps1_addr;
                    ps2_addr[MUL_START + counterB] = rs_entry_arr[i].ps2_addr;
                    counterB = counterB + 1;
                    if(counterB == MUL_COUNT)
                        break;
                end
            end
        end
        
        counterE = 0;
        for(int unsigned i = 0; i < DIV_COUNT; i++) begin
            div_rs_entry_valid[i] = '0;
            div_rs_entry_dout[i] = 'x;
            div_out_idx[i] = 'x;
        end
        for(int unsigned i = 0; i < DEPTH; i++) begin
            if(rs_arr_inuse[i] && rs_entry_arr[i].ps1_valid && rs_entry_arr[i].ps2_valid) begin
                if(rs_entry_arr[i].opcode == op_b_reg && rs_entry_arr[i].funct7 == mult_div && rs_entry_arr[i].funct3[2]) begin
                    div_out_idx[counterE] = (DEPTH_BITS)'(i);
                    div_rs_entry_valid[counterE] = '1;
                    div_rs_entry_dout[counterE] = rs_entry_arr[i];
                    ps1_addr[DIV_START + counterE] = rs_entry_arr[i].ps1_addr;
                    ps2_addr[DIV_START + counterE] = rs_entry_arr[i].ps2_addr;
                    counterE = counterE + 1;
                    if(counterE == DIV_COUNT)
                        break;
                end
            end
        end
        
        counterC = 0;
        for(int unsigned i = 0; i < BRANCH_COUNT; i++) begin
            branch_rs_entry_valid[i] = '0;
            branch_rs_entry_dout[i] = 'x;
            branch_out_idx[i] = 'x;
        end
        for(int unsigned i = 0; i < DEPTH; i++) begin
            if(rs_arr_inuse[i] && rs_entry_arr[i].ps1_valid && rs_entry_arr[i].ps2_valid) begin
                if(rs_entry_arr[i].opcode == op_b_br || rs_entry_arr[i].opcode == op_b_jal || rs_entry_arr[i].opcode == op_b_jalr) begin
                    branch_out_idx[counterC] = (DEPTH_BITS)'(i);
                    branch_rs_entry_valid[counterC] = '1;
                    branch_rs_entry_dout[counterC] = rs_entry_arr[i];
                    ps1_addr[BRANCH_START + counterC] = rs_entry_arr[i].ps1_addr;
                    ps2_addr[BRANCH_START + counterC] = rs_entry_arr[i].ps2_addr;
                    counterC = counterC + 1;
                    if(counterC == BRANCH_COUNT)
                        break;
                end
            end
        end
        
        counterD = 0;
        for(int unsigned i = 0; i < LS_COUNT; i++) begin
            ls_rs_entry_valid[i] = '0;
            ls_rs_entry_dout[i] = 'x;
            ls_out_idx[i]       = 'x;
        end
        for(int unsigned i = 0; i < DEPTH; i++) begin
            if(rs_arr_inuse[i] && rs_entry_arr[i].ps1_valid && rs_entry_arr[i].ps2_valid) begin
                if(rs_entry_arr[i].opcode == op_b_load || rs_entry_arr[i].opcode == op_b_store) begin
                    ls_out_idx[counterD] = (DEPTH_BITS)'(i);
                    ls_rs_entry_valid[counterD] = '1;
                    ls_rs_entry_dout[counterD] = rs_entry_arr[i];
                    ps1_addr[LS_START + counterD] = rs_entry_arr[i].ps1_addr;
                    ps2_addr[LS_START + counterD] = rs_entry_arr[i].ps2_addr;
                    counterD = counterD + 1;
                    if(counterD == LS_COUNT)
                        break;
                end
            end
        end
    end

    // assign inuse array
    always_ff @ (posedge clk) begin
        if (rst) begin
            for (int i = 0; i < DEPTH; i++) begin
                rs_arr_inuse[i] <= 1'b0;
            end
            for (int i = 0; i < CDB_COUNT; i++) begin
                lagged_cdb[i] <= '0;
            end
        end else begin
            for(int i = 0; i < NSIZE; i++) begin
                if(rs_enqueue[i]) begin
                    rs_arr_inuse[free_idx[i]] <= 1'b1;
                    rs_entry_arr[free_idx[i]] <= rs_entry_din[i];
                end
            end
            for(int i = 0; i < BASE_COUNT; i++) begin
                if(base_fn_ready[i] && base_rs_entry_valid[i])
                    rs_arr_inuse[base_out_idx[i]] <= 1'b0;
            end
            for(int i = 0; i < MUL_COUNT; i++) begin
                if(mul_fn_ready[i] && mul_rs_entry_valid[i])
                    rs_arr_inuse[mul_out_idx[i]] <= 1'b0;
            end
            for(int i = 0; i < DIV_COUNT; i++) begin
                if(div_fn_ready[i] && div_rs_entry_valid[i])
                    rs_arr_inuse[div_out_idx[i]] <= 1'b0;
            end
            for(int i = 0; i < BRANCH_COUNT; i++) begin
                if(branch_fn_ready[i] && branch_rs_entry_valid[i])
                    rs_arr_inuse[branch_out_idx[i]] <= 1'b0;
            end
            for(int i = 0; i < LS_COUNT; i++) begin
                if(ls_fn_ready[i] && ls_rs_entry_valid[i])
                    rs_arr_inuse[ls_out_idx[i]] <= 1'b0;
            end
            for(int j = 0; j < CDB_COUNT; j++) begin
                lagged_cdb[j] <= cdb[j];
                for (int i = 0; i < DEPTH; i++) begin
                    if (rs_arr_inuse[i] && cdb[j].ready && cdb[j].pr_dest == rs_entry_arr[i].ps1_addr) begin
                        rs_entry_arr[i].ps1_valid <= 1'b1;
                    end
                    if (rs_arr_inuse[i] && cdb[j].ready && cdb[j].pr_dest == rs_entry_arr[i].ps2_addr) begin
                        rs_entry_arr[i].ps2_valid <= 1'b1;
                    end
                    if (rs_arr_inuse[i] && lagged_cdb[j].ready && lagged_cdb[j].pr_dest == rs_entry_arr[i].ps1_addr) begin
                        rs_entry_arr[i].ps1_valid <= 1'b1;
                    end
                    if (rs_arr_inuse[i] && lagged_cdb[j].ready && lagged_cdb[j].pr_dest == rs_entry_arr[i].ps2_addr) begin
                        rs_entry_arr[i].ps2_valid <= 1'b1;
                    end
                end
            end
        end
    end
    
endmodule
