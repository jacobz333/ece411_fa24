package rv32i_types;

    localparam CONST_NSIZE = 2;
    localparam CONST_NSIZE_INSTRUCTIONS = 4;
    localparam CONST_IQSIZE_BITS = 3;
    localparam CONST_ROBSIZE_BITS = 5;
    localparam CONST_PR_BITS = 6;
    localparam CONST_LSQSIZE_BITS = 3;
    localparam CONST_BQSIZE_BITS = 2;
    localparam CONST_RSSIZE_BITS = 3;

    typedef enum logic [6:0] {
        op_b_lui       = 7'b0110111, // load upper immediate (U type)
        op_b_auipc     = 7'b0010111, // add upper immediate PC (U type)
        op_b_jal       = 7'b1101111, // jump and link (J type)
        op_b_jalr      = 7'b1100111, // jump and link register (I type)
        op_b_br        = 7'b1100011, // branch (B type)
        op_b_load      = 7'b0000011, // load (I type)
        op_b_store     = 7'b0100011, // store (S type)
        op_b_imm       = 7'b0010011, // arith ops with register/immediate operands (I type)
        op_b_reg       = 7'b0110011  // arith ops with register operands (R type)
    } rv32i_opcode;

    typedef enum logic [2:0] {
        arith_f3_add   = 3'b000, // check logic 30 for sub if op_reg op
        arith_f3_sll   = 3'b001,
        arith_f3_slt   = 3'b010,
        arith_f3_sltu  = 3'b011,
        arith_f3_xor   = 3'b100,
        arith_f3_sr    = 3'b101, // check logic 30 for logical/arithmetic
        arith_f3_or    = 3'b110,
        arith_f3_and   = 3'b111
    } arith_f3_t;

    typedef enum logic [2:0] {
        load_f3_lb     = 3'b000,
        load_f3_lh     = 3'b001,
        load_f3_lw     = 3'b010,
        load_f3_lbu    = 3'b100,
        load_f3_lhu    = 3'b101
    } load_f3_t;

    typedef enum logic [2:0] {
        store_f3_sb    = 3'b000,
        store_f3_sh    = 3'b001,
        store_f3_sw    = 3'b010
    } store_f3_t;

    typedef enum logic [2:0] {
        branch_f3_beq  = 3'b000,
        branch_f3_bne  = 3'b001,
        branch_f3_blt  = 3'b100,
        branch_f3_bge  = 3'b101,
        branch_f3_bltu = 3'b110,
        branch_f3_bgeu = 3'b111
    } branch_f3_t;

    typedef enum logic [2:0] {
        alu_op_add     = 3'b000,
        alu_op_sll     = 3'b001,
        alu_op_sra     = 3'b010,
        alu_op_sub     = 3'b011,
        alu_op_xor     = 3'b100,
        alu_op_srl     = 3'b101,
        alu_op_or      = 3'b110,
        alu_op_and     = 3'b111
    } alu_ops;

    
    typedef enum logic [2:0] {
        mult_div_op_mul     = 3'b000,
        mult_div_op_mulh    = 3'b001,
        mult_div_op_mulhsu  = 3'b010,
        mult_div_op_mulhu   = 3'b011,
        mult_div_op_div     = 3'b100,
        mult_div_op_divu    = 3'b101,
        mult_div_op_rem     = 3'b110,
        mult_div_op_remu    = 3'b111
    } mul_div_ops;

    // You'll need this type to randomly generate variants of certain
    // instructions that have the funct7 field.
    typedef enum logic [6:0] {
        base           = 7'b0000000,
        variant        = 7'b0100000,
        mult_div       = 7'b0000001
    } funct7_t;

    // Various ways RISC-V instruction words can be interpreted.
    // See page 104, Chapter 19 RV32/64G Instruction Set Listings
    // of the RISC-V v2.2 spec.
    typedef union packed {
        logic [31:0] word;

        struct packed {
            logic [11:0] i_imm;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  rd;
            rv32i_opcode opcode;
        } i_type;

        struct packed {
            logic [6:0]  funct7;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  rd;
            rv32i_opcode opcode;
        } r_type;

        struct packed {
            logic [11:5] imm_s_top;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  imm_s_bot;
            rv32i_opcode opcode;
        } s_type;

        struct packed {
            logic [12:12]   b_imm_12;
            logic [10:5]    b_imm_upper;
            logic [4:0]     rs2;
            logic [4:0]     rs1;
            logic [2:0]     funct3;
            logic [4:1]     b_imm_lower;
            logic [11:11]   b_imm_11;
            rv32i_opcode    opcode;
        } b_type;

        struct packed {
            logic [31:12] imm;
            logic [4:0]   rd;
            rv32i_opcode  opcode;
        } j_type;

    } instr_t;

    localparam nop = 32'h00000013;
    localparam rst_addr = 32'h1eceb000;
    localparam mistake = 32'hfadedace; // DEBUG

    typedef struct packed {
        logic         ready;
        logic [CONST_PR_BITS-1:0]   pr_dest; 
    
        logic [63:0]  monitor_order;
        logic [31:0]  monitor_inst;
        logic [4:0]   monitor_rs1_addr;
        logic [4:0]   monitor_rs2_addr;
        logic [31:0]  monitor_rs1_rdata;
        logic [31:0]  monitor_rs2_rdata;
        logic         monitor_regf_we;
        logic [4:0]   monitor_rd_addr;
        logic [31:0]  monitor_rd_wdata;
        logic [31:0]  monitor_pc_rdata;
        logic [31:0]  monitor_pc_wdata;
        logic [31:0]  monitor_mem_addr;
        logic [3:0]   monitor_mem_rmask;
        logic [3:0]   monitor_mem_wmask;
        logic [31:0]  monitor_mem_rdata;
        logic [31:0]  monitor_mem_wdata;
    } rob_entry_t;
    
    typedef struct packed {
        logic         ready;
        logic [CONST_ROBSIZE_BITS-1:0] rob_id;
        logic [CONST_PR_BITS-1:0] pr_dest;
        logic [4:0]   ar_dest;
        logic         is_load;
        logic [2:0]   funct3;
        logic [3:0]   mask;
        logic [31:0]  addr;
        logic [31:0]  wdata;
        
        logic [31:0]  monitor_rs1_rdata;
        logic [31:0]  monitor_rs2_rdata;
    } lsq_entry_t;
     
    typedef struct packed {
        logic ready;
        logic [CONST_LSQSIZE_BITS-1:0] lsq_id;
        
        logic [3:0]  mask;
        logic [31:0] addr;
        logic [31:0] wdata;
    
        logic [31:0] monitor_rs1_rdata; // from phys regfile
        logic [31:0] monitor_rs2_rdata; // from phys regfile
    } lsq_bus_t;
    
    typedef struct packed {
        logic       ready;
        logic [CONST_ROBSIZE_BITS-1:0] rob_id; // Size ROBSIZE_BITS (Number of elements in ROB)
        logic [4:0] ar_dest; // architectural reg
        logic [CONST_PR_BITS-1:0] pr_dest; // Size PR_BITS (Number of physical registers in system)
        logic [31:0] result;

        logic [31:0] monitor_rs1_rdata; // from phys regfile
        logic [31:0] monitor_rs2_rdata; // from phys regfile
        
        // Load specific info (store info sent directly to commit logic)
        logic [3:0] monitor_mem_rmask;
        logic [31:0] monitor_mem_addr;
        logic [31:0] monitor_mem_rdata;
    } cdb_t;
    
    typedef struct packed {
        logic [31:0] instruction;
        logic [31:0] pc;
        logic [63:0] order;
    } iq_entry_t;

    // reservation station entry
    typedef struct packed {
        logic   [CONST_ROBSIZE_BITS-1:0]   rob_id;     // ROBSIZE_BITS
        logic   [31:0]  imm;        // immediate value, properly shifted
        logic   [CONST_PR_BITS-1:0]   ps1_addr;   // PR_BITS
        logic           ps1_valid;
        logic   [CONST_PR_BITS-1:0]   ps2_addr;   // PR_BITS
        logic           ps2_valid;
        logic   [4:0]   rd_addr;    // architectural destination
        logic   [CONST_PR_BITS-1:0]   pd_addr;    // PR_BITS
        rv32i_opcode    opcode;
        logic   [2:0]   funct3;
        logic   [6:0]   funct7;
        logic   [CONST_LSQSIZE_BITS-1:0]   lsq_id;
        logic   [CONST_BQSIZE_BITS-1:0]   bq_id;
        logic   [31:0]  PC;
        logic   [63:0]  order;
    } rs_entry_t;
    
    // branch queue bus 
    typedef struct packed {
        logic                               branch_taken;
        logic   [31:0]                      branch_target;
        logic                               ready;
        logic   [CONST_BQSIZE_BITS-1:0]     bq_id;
    } bq_bus_t;

    // branch queue entry 
    typedef struct packed {
        logic                               branch_taken;
        logic   [31:0]                      branch_target;
        logic   [63:0]                      branch_order;
    } bq_entry_t;

    typedef struct packed {
        logic   [3:0]   wmask;
        logic   [31:0]  addr;
        logic   [31:0]  wdata;
    } sb_entry_t;

endpackage

