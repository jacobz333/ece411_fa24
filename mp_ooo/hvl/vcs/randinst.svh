// This class generates random valid RISC-V instructions to test your
// RISC-V cores.


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

    
class RandInst;
    // You will increment this number as you generate more random instruction
    // types. Once finished, NUM_TYPES should be 9, for each opcode type in
    // rv32i_opcode.
    localparam NUM_TYPES = 10;

    // Note that the `instr_t` type is from ../pkg/types.sv, there are TODOs
    // you must complete there to fully define `instr_t`.
    rand instr_t instr;
    rand bit [NUM_TYPES-1:0] instr_type;
    rand bit [7:0] funct3_intermediate;

    // Make sure we have an even distribution of instruction types.
    constraint solve_order_c { solve instr_type before instr; }

    // Hint/TODO: you will need another solve_order constraint for funct3
    // to get 100% coverage with 500 calls to .randomize().
    constraint solve_order_funct3_c {
        solve funct3_intermediate before instr;
        $countones(funct3_intermediate) == 1;
        funct3_intermediate[0] -> instr.i_type.funct3 == 3'b000;
        funct3_intermediate[1] -> instr.i_type.funct3 == 3'b001;
        funct3_intermediate[2] -> instr.i_type.funct3 == 3'b010;
        funct3_intermediate[3] -> instr.i_type.funct3 == 3'b011;
        funct3_intermediate[4] -> instr.i_type.funct3 == 3'b100;
        funct3_intermediate[5] -> instr.i_type.funct3 == 3'b101;
        funct3_intermediate[6] -> instr.i_type.funct3 == 3'b110;
        funct3_intermediate[7] -> instr.i_type.funct3 == 3'b111;
    }

    // Pick one of the instruction types.
    constraint instr_type_c {
        $countones(instr_type) == 1; // Ensures one-hot.
    }

    // Constraints for actually generating instructions, given the type.
    // Again, see the instruction set listings to see the valid set of
    // instructions, and constrain to meet it. Refer to ../pkg/types.sv
    // to see the typedef enums.

    constraint instr_c {
        // Reg-imm instructions
        instr_type[0] -> {
            instr.i_type.opcode == op_b_imm;

            // Implies syntax: if funct3 is arith_f3_sr, then funct7 must be
            // one of two possibilities.
            instr.i_type.funct3 == arith_f3_sr -> {
                // Use r_type here to be able to constrain funct7.
                instr.r_type.funct7 inside {base, variant};
            }

            // This if syntax is equivalent to the implies syntax above
            // but also supports an else { ... } clause.
            if (instr.i_type.funct3 == arith_f3_sll) {
                instr.r_type.funct7 == base;
            }
        }
        /*
            typedef enum logic [2:0] {
        arith_f3_add   = 3'b000, // check logic 30 for sub if op_reg op
        arith_f3_sll   = 3'b001,
        arith_f3_slt   = 3'b010,
        arith_f3_sltu  = 3'b011,
        arith_f3_xor   = 3'b100,
        arith_f3_sr    = 3'b101, // check logic 30 for logical/arithmetic
        arith_f3_or    = 3'b110,
        arith_f3_and   = 3'b111
    } arith_f3_t;*/

        // Reg-reg instructions
        instr_type[1] -> {
            // TODO: Fill this out!
            instr.r_type.opcode == op_b_reg;
            
            if(instr.i_type.funct3 inside {arith_f3_add, arith_f3_sr}) {
                instr.r_type.funct7 inside {base, variant};
            }
            else {
                instr.r_type.funct7 == base;
            }
        }

        // Store instructions -- these are easy to constrain!
        instr_type[2] -> {
            instr.s_type.opcode == op_b_store;
            instr.s_type.funct3 inside {store_f3_sb, store_f3_sh, store_f3_sw};
            
            // LAZY CONSTRAINT, CHANGE LATER
            // instr.s_type.rs1 == 5'b00000;
            // instr.s_type.imm_s_bot[1:0] == 2'b00;
        }

        // Load instructions
        instr_type[3] -> {
            instr.i_type.opcode == op_b_load;
        // TODO: Constrain funct3 as well.
        
            instr.i_type.funct3 inside {load_f3_lb, load_f3_lh, load_f3_lw, load_f3_lbu, load_f3_lhu};
            
            // LAZY CONSTRAINT, CHANGE LATER
            // instr.i_type.rs1 == 5'b00000;
            // instr.i_type.i_imm[1:0] == 2'b00;
        }
        
        /*
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
    } rv32i_opcode;*/

        // TODO: Do all 9 types!
        instr_type[4] -> {
            instr.i_type.opcode == op_b_lui;
        }
        
        instr_type[5] -> {
            instr.i_type.opcode == op_b_auipc;
        }
        
        instr_type[6] -> {
            instr.i_type.opcode == op_b_jal;
        }
        
        instr_type[7] -> {
            instr.i_type.opcode == op_b_jalr;
            instr.i_type.funct3 == 3'b000;
        }
        
        instr_type[8] -> {
            instr.i_type.opcode == op_b_br;
            instr.i_type.funct3 inside {branch_f3_beq, branch_f3_bne, branch_f3_blt, branch_f3_bge, branch_f3_bltu, branch_f3_bgeu};
        }
        
        // generate mult and div and rem instructions
        instr_type[9] -> {
            instr.i_type.opcode == op_b_reg;
            instr.r_type.funct7 == mult_div;

            // instr.r_type.funct3 == mult_div_op_mulhsu;
        }
    }

    `include "../../hvl/vcs/instr_cg.svh"

    // Constructor, make sure we construct the covergroup.
    function new();
        instr_cg = new();
    endfunction : new

    // Whenever randomize() is called, sample the covergroup. This assumes
    // that every time you generate a random instruction, you send it into
    // the CPU.
    function void post_randomize();
        instr_cg.sample(this.instr);
    endfunction : post_randomize

    // A nice part of writing constraints is that we get constraint checking
    // for free -- this function will check if a bit vector is a valid RISC-V
    // instruction (assuming you have written all the relevant constraints).
    function bit verify_valid_instr(instr_t inp);
        bit valid = 1'b0;
        this.instr = inp;
        for (int i = 0; i < NUM_TYPES; ++i) begin
            this.instr_type = 1 << i;
            if (this.randomize(null)) begin
                valid = 1'b1;
                break;
            end
        end
        return valid;
    endfunction : verify_valid_instr

endclass : RandInst