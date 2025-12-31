// This class generates random valid RISC-V instructions to test your
// RISC-V cores.

class RandInst;
    // You will increment this number as you generate more random instruction
    // types. Once finished, NUM_TYPES should be 9, for each opcode type in
    // rv32i_opcode.
    localparam NUM_TYPES = 9;

    // Note that the `instr_t` type is from ../pkg/types.sv
    rand instr_t instr;
    rand bit [NUM_TYPES-1:0] instr_type;

    // Make sure we have an even distribution of instruction types.
    constraint solve_order_c { solve instr_type before instr; }

    // solve_order constraint for funct3 to get 100% coverage with 500 calls to .randomize().
    rand logic [2:0] instr_funct3;
    rand logic [6:0] instr_funct7;
    constraint solve_order_funct3_c {
        instr_funct3 == instr.r_type.funct3;
        instr_funct7 == instr.r_type.funct7;

        solve instr_funct3 before instr_funct7;
    }

    // Pick one of the instruction types.
    constraint instr_type_c {
        $countones(instr_type) == 1; // Ensures one-hot.

        // make sure all non-memory instructions are checked
        // instr_type[2] == 0;
        // instr_type[3] == 0;
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

        // Reg-reg instructions
        instr_type[1] -> {
            // constrain opcode
            instr.i_type.opcode == op_b_reg;

            // constrain funct3
            if (instr.i_type.funct3 == arith_f3_add) { // ADD or SUB
                instr.r_type.funct7 inside {base, variant};
            } else if (instr.i_type.funct3 == arith_f3_sr) { // SRL or SRA
                instr.r_type.funct7 inside {base, variant}; 
            } else { // otherwise must be base
                instr.r_type.funct7 == base;
            }    
        }

        // Store instructions -- these are easy to constrain!
        instr_type[2] -> {
            instr.s_type.opcode == op_b_store;
            instr.s_type.funct3 inside {store_f3_sb, store_f3_sh, store_f3_sw};

            // // constraints to avoid trap mismatch
            // instr.s_type.rs1 == 5'b00000;
            // if (instr.s_type.funct3 == store_f3_sw) {
            //     instr.s_type.imm_s_bot[1:0] == 2'b00;
            // } else if (instr.s_type.funct3 == store_f3_sh) {
            //     instr.s_type.imm_s_bot[0] == 1'b0;
            // }
        }

        // Load instructions
        instr_type[3] -> {
            instr.i_type.opcode == op_b_load;

            instr.i_type.funct3 inside {load_f3_lb, load_f3_lh, load_f3_lw, load_f3_lbu, load_f3_lhu};
        
            // // constraints to avoid trap mismatch
            // instr.i_type.rs1 == 5'b00000;
            // if (instr.i_type.funct3 == load_f3_lw) {
            //     instr.i_type.i_imm[1:0] == 2'b00;
            // } else if (instr.i_type.funct3 inside {store_f3_sh, load_f3_lhu}) {
            //     instr.i_type.i_imm[0] == 1'b0;
            // }
        }

        // Branch instructions
        instr_type[4] -> {
            instr.b_type.opcode == op_b_store;

            // instr.b_type.funct3 inside {branch_f3_beq, branch_f3_bne, branch_f3_blt, branch_f3_bge, branch_f3_bltu, branch_f3_bgeu};
        }

        // JALR instruction
        instr_type[5] -> {
            instr.i_type.opcode == op_b_store;

            // instr.i_type.funct3 == 3'b000;
        }

        // JAL instruction
        instr_type[6] -> {
            instr.j_type.opcode == op_b_store;
        }

        // AUIPC instruction
        instr_type[7] -> {
            instr.j_type.opcode == op_b_auipc;
        }

        // LUI instruction
        instr_type[8] -> {
            instr.j_type.opcode == op_b_lui;
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
