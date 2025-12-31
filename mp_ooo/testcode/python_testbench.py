import random

instr_types = [
               "op_lui",
               "op_auipc",
               "op_jal",
               "op_jalr",
               "op_br",
               "op_load",
               "op_store",
               "op_imm",
               "op_reg",
               "op_muldiv"]

br_types = ["beq",
            "bne",
            "blt",
            "bge",
            "bltu",
            "bgeu"]

ld_types = ["lb",
            "lh",
            "lw",
            "lbu",
            "lhu"]

st_types = ["sb",
            "sh",
            "sw"]

imm_types = ["addi",
             "slti",
             "sltiu",
             "xori",
             "ori",
             "andi",
             "slli",
             "srai"]

reg_types = ["add",
             "sub",
             "sll",
             "slt",
             "sltu",
             "xor",
             "srl",
             "sra",
             "or",
             "and"]

muldiv_types = ["mul",
                "mulh",
                "mulhsu",
                "mulhu",
                "div",
                "divu",
                "rem",
                "remu"]

# probability distribution
weights = [
            0.01, # lui
            0.01, # auipc
            0.01, # jal
            0.01, # jalr
            0.01, # br
            0.50, # load
            0.10, # store
            0.01, # imm
            0.01, # reg
            0.00  # muldiv
            ]

# number of instructions to generate
random.seed(0) # random seed 
num_instr = 10000
pc_start = 0x1eceb000
mem_start = pc_start + 4*(num_instr + 100)
mem_length = 0xe1315000 + pc_start - mem_start - 4 # see spike command in Makefile
# mem_length = 4*64
mem_end = mem_start + mem_length
print(f"mem bounds: 0x{mem_start:08x} : 0x{mem_end:08x}")
# assert mem_end < pc_start + 0xe1315000, "invalid memory length!"

jmp_limit = 4 # how many instructions can be skipped for jumps/branches
reg_num = 10 # number of registers
label_range = 10 # prevent compiler from inserting jumps for large 
label_name = "_" # label name
comment = "should not execute" # what do i say when the instruction should be skipped?

# initialize
order = 0
total_num_instr = 0
pc = pc_start
regfile = [0 for _ in range(reg_num)]
regfile_valid = [False for _ in range(reg_num)]
regfile_valid[0] = True
memory = dict() # dictionary of addr -> data
label_num = 0 # number of jumps to determine labels
load_instr_count = 0
store_instr_count = 0


file = open("python_test.s", "w")

def unsigned(data):
    return data & 0xffffffff

# sign extend value starting with bit length
def sign_extend(value, bit_len):
    # print(bit_len)
    # print(f"value=0b{value:032b}")
    mask = ~(-1 << bit_len) # of the form 0x00FF up to bit length
    # print(f"mask=0b{mask:032b}")
    # extract bit
    bit = (value >> (bit_len - 1)) & 1
    # apply mask
    if bit: # 1
        return value | ~mask
    else: # 0
        return value & mask

def check_addr(byte_addr, num_bytes, read=True):
    # ensure address works for spike
    if not (mem_start <= byte_addr < mem_end):
        # print("fail!")
        return False
    # # check alignment
    # if align_type == "word":
    #     return byte_addr % 4 == 0
    # if align_type == "half":
    #     return byte_addr % 2 == 0
    # if align_type == "byte":
    #     return True
    # ensure that we read from a useful memory address
    if read:
        # num_bytes = 0
        # if align_type == "word":
        #     num_bytes = 4
        # if align_type == "half":
        #     num_bytes = 2
        # if align_type == "byte":
        #     num_bytes = 1
        for i in range(num_bytes):
            if byte_addr + i not in memory:
                # print(f"0x{byte_addr:08x} not in memory")
                return False
    return True
    # ok smth weird happened
    raise ValueError(f"invalid input to check_addr: byte_addr={byte_addr}, align_type={align_type}")
    return False # realistically never get here

def check_jmp_addr(addr):
    # ensure address points to a valid instruction
    if not (pc_start <= addr < pc_start + 4*num_instr):
        # print("fail")
        return False
    # check alignment
    if not (addr % 4 == 0):
        # print("fail1")
        return False
    # address is good!
    return True

def write_regfile(addr, data):
    assert 0 <= addr < reg_num, f"reg addr={addr} must be in range!"
    if addr != 0:
        regfile_valid[addr] = True
        regfile[addr] = unsigned(data)

def read_regfile(addr):
    assert 0 <= addr < reg_num, f"reg addr={addr} must be in range!"
    # assert regfile_valid[addr]
    return regfile[addr]

def write_mem(byte_addr, data, num_bytes):
    assert num_bytes == 1 or num_bytes == 2 or num_bytes == 4, "strange load!"
    for i in range(num_bytes):
        memory[byte_addr+i] = (data >> 8*i) & 0xFF

def read_mem(byte_addr, num_bytes):
    assert num_bytes == 1 or num_bytes == 2 or num_bytes == 4, "strange store!" 
    rdata = 0
    for i in range(num_bytes):
        assert byte_addr + i in memory, f"cannot read from this byte address! 0x{byte_addr + i:08x}"
        rdata |= (memory[byte_addr+i] << 8*i)
    return unsigned(rdata)

def comparator(br_type, a, b):
    au = unsigned(a)
    bu = unsigned(b)
    a_s = sign_extend(a, 32)
    b_s = sign_extend(b, 32)
    br_en = True
    if   br_type == "beq":
        br_en = (au == bu)
    elif br_type == "bne":
        br_en = (au != bu)
    elif br_type == "blt":
        br_en = (a_s < b_s)
    elif br_type == "bge":
        br_en = (a_s >= b_s)
    elif br_type == "bltu":
        br_en = (au  < bu)
    elif br_type == "bgeu":
        br_en = (au >= bu)
    else:
        assert False, "bad cmp!"
    return br_en

def alu(aluop, a, b):
    au = unsigned(a)
    bu = unsigned(b)
    a_s = sign_extend(a, 32)
    b_s = sign_extend(b, 32)
    result = 0
    if   aluop == "add":
        result = au + bu
    elif aluop == "sll":
        result = au << (bu % 32)
    elif aluop == "sra":
        result = a_s >> (bu % 32)
    elif aluop == "sub":
        result = au - bu
    elif aluop == "xor":
        result = au ^ bu
    elif aluop == "srl":
        result = au >> (bu % 32)
    elif aluop == "or":
        result = au | bu
    elif aluop == "and":
        result = au & bu
    else:
        assert False, "bad aluop!"
    
    return unsigned(result)

def muldiv_alu(muldiv_type, a, b):
    au = unsigned(a)
    bu = unsigned(b)
    a_s = sign_extend(a, 32)
    b_s = sign_extend(b, 32)
    result = 0
    
    if   muldiv_type == "mul":
        result = a_s * b_s
    elif muldiv_type == "mulh":
        result = (a_s * b_s) >> 32
    elif muldiv_type == "mulhsu":
        result = (a_s * bu) >> 32
    elif muldiv_type == "mulhu":
        result = (au * bu) >> 32
    elif muldiv_type == "div":
        if (b_s == 0):
            result = 0xFFFFFFFF
        else:
            result = a_s // b_s
    elif muldiv_type == "divu":
        if (bu == 0):
            result = 0xFFFFFFFF
        else:
            result = au // bu
    elif muldiv_type == "rem":
        if (b_s == 0):
            result = a_s
        else:
            result = a_s % b_s 
    elif muldiv_type == "remu":
        if (bu == 0):
            result = au
        else:
            result = au % bu
    else:
        assert False, "bad muldiv_type!"
    
    return unsigned(result)

# generate a certain number of garbage instructions
def gen_garbage(num):
    for _ in range(num):
        file.write("\t") # identifier for skipped instructions
        # pick an instruction type
        instr = random.choices(instr_types, weights)[0]
        # shared random values
        rs1 = random.randint(0, reg_num-1)
        rs2 = random.randint(0, reg_num-1)
        rd  = random.randint(0, reg_num-1)
        txtr1 = f"x{rs1}"
        txtr2 = f"x{rs2}"
        txtrd = f"x{rd}"
        imm_12  = random.randint(-2**11, 2**11-1)
        if   instr == "op_lui":
            u_imm = random.randint(0, 2**20-1)
            # print(f"lui\t{txtrd:>3}, {u_imm:>8}\t# {comment}")
            instrtxt = "lui"
            instrtxt = f"{instrtxt:<8}"
            file.write(f"{instrtxt}{txtrd:>3}, {u_imm:>8}\t\t# {comment}\n")
        elif instr == "op_auipc":
            u_imm = random.randint(0, 2**20-1)
            # print(f"auipc\t{txtrd:>3}, {u_imm:>8}\t# {comment}")
            instrtxt = "auipc"
            instrtxt = f"{instrtxt:<8}"
            file.write(f"{instrtxt}{txtrd:>3}, {u_imm:>8}\t\t# {comment}\n")
        elif instr == "op_jal":
            # pick random
            j_imm  = random.randint(-2**19, 2**19-1)
            val = (j_imm << 1) & ~0x3 # 4 byte align
            # print
            rand_label = max(0, label_num-1 - random.randint(0, label_range))
            # rand_label = random.randint(0, max(label_num-1,0))
            rand_label_txt = f"{label_name}{rand_label}"
            # print(f"jal\t{txt:>3}, {rand_label_txt:>10}\t# {comment}")
            instrtxt = "jal"
            instrtxt = f"{instrtxt:<8}"
            file.write(f"{instrtxt}{txtrd:>3}, {rand_label_txt:>10}\t\t# {comment}\n")
        elif instr == "op_jalr":
            # pick random
            val = (imm_12) & ~0x3 # 4 byte align
            # print
            # print(f"jalr\t{txtrd:>3}, {val:>5}({txtr1:>3})\t# {comment}")
            instrtxt = "jalr"
            instrtxt = f"{instrtxt:<8}"
            file.write(f"{instrtxt}{txtrd:>3}, {val:>5}({txtr1:>3})\t\t# {comment}\n")
        elif instr == "op_br":
            # pick random
            br_type = random.choice(br_types)
            # val = (imm_12 << 1) & ~0x3 # 4 byte align
            # print
            rand_label = max(0, label_num-1 - random.randint(0, label_range))
            # rand_label = random.randint(0, max(label_num-1,0))
            rand_label_txt = f"{label_name}{rand_label}"
            # print(f"{br_type}\t{txtr1:>3}, {txtr2:>3}, {rand_label_txt}\t# {comment}")
            instrtxt = f"{br_type:<8}"
            file.write(f"{instrtxt}{txtr1:>3}, {txtr2:>3}, {rand_label_txt}+{0:>3}\t# {comment}\n")
        elif instr == "op_load":
            ld_type = random.choice(ld_types)
            # print
            # print(f"{ld_type}\t{txtrd:>3}, {imm_12:>5}({txtr1:>3})\t# {comment}")
            instrtxt = f"{ld_type:<8}"
            file.write(f"{instrtxt}{txtrd:>3}, {imm_12:>5}({txtr1:>3})\t\t# {comment}\n")
        elif instr == "op_store":
            st_type = random.choice(st_types)
            # print
            # print(f"{st_type}\t{txtr1:>3}, {imm_12:>5}({txtr2:>3})\t# {comment}")
            instrtxt = f"{st_type:<8}"
            file.write(f"{instrtxt}{txtr1:>3}, {imm_12:>5}({txtr2:>3})\t\t# {comment}\n")
        elif instr == "op_imm":
            imm_type = random.choice(imm_types)
            instrtxt = f"{imm_type:<8}"
            if imm_type in ["slli", "srli", "srai"]:
                shift_imm   = random.randint(0, 31)
                # print
                # print(f"{imm_type}\t{txtrd:>3}, {txtr1:>3}, {shift_imm:>5}\t# {comment}")
                file.write(f"{instrtxt}{txtrd:>3}, {txtr1:>3}, {shift_imm:>5}\t\t# {comment}\n")
            else:
                # print
                # print(f"{imm_type}\t{txtrd:>3}, {txtr1:>3}, {imm_12:>5}\t# {comment}")
                file.write(f"{instrtxt}{txtrd:>3}, {txtr1:>3}, {imm_12:>5}\t\t# {comment}\n")
        elif instr == "op_reg":
            reg_type = random.choice(reg_types)
            # print
            # print(f"{reg_type}\t{txtrd:>3}, {txtr1:>3}, {txtr2:>3}\t# {comment}")
            instrtxt = f"{reg_type:<8}"
            file.write(f"{instrtxt}{txtrd:>3}, {txtr1:>3}, {txtr2:>3}\t\t# {comment}\n")
        elif instr == "op_muldiv":
            muldiv_type = random.choice(muldiv_types)
            # print
            # print(f"{muldiv_type}\t{txtrd:>3}, {txtr1:>3}, {txtr2:>3}\t# {comment}")
            instrtxt = f"{muldiv_type:<8}"
            file.write(f"{instrtxt}{txtrd:>3}, {txtr1:>3}, {txtr2:>3}\t\t# {comment}\n")

# print(".section .text")
# print(".globl _start")
# print("_start:")
file.write(".section .text\n.globl _start\n_start:\n")

while total_num_instr < num_instr:
    # 

    # pick an instruction type
    instr = random.choices(instr_types, weights)[0]
    oldpc = pc
    info_txt = f"order=0x{order:08x}, pc=0x{oldpc:08x}"
    # shared random values
    rs1 = random.randint(0, reg_num-1)
    rs2 = random.randint(0, reg_num-1)
    rd  = random.randint(0, reg_num-1)
    rs1_val = read_regfile(rs1)
    rs2_val = read_regfile(rs2)
    txtr1 = f"x{rs1}"
    txtr2 = f"x{rs2}"
    txtrd = f"x{rd}"
    imm_12 = random.randint(-2**11, 2**11-1)
    labeltxt = f"{label_name}{label_num}"
    if   instr == "op_lui":
        # pick random
        u_imm = random.randint(0, 2**20-1)
        val = unsigned(u_imm << 12)
        # execute
        write_regfile(rd, val)
        pc = pc + 4
        # print
        # print(f"lui\t{txtrd:>3}, {u_imm:>8}\t# r{rd:<2} <- 0x{val:08x}, {info_txt}")
        instrtxt = "lui"
        instrtxt = f"{instrtxt:<8}"
        file.write(f"\t{instrtxt}{txtrd:>3}, {u_imm:>8}\t\t# r{rd:<2} <- 0x{val:08x}, \t\t\t\t{info_txt}\n")
        total_num_instr += 1
        order += 1
    elif instr == "op_auipc":
        # pick random
        u_imm = random.randint(0, 2**20-1)
        val = unsigned((u_imm << 12) + pc)
        # execute
        write_regfile(rd, val)
        pc = pc + 4
        # print
        instrtxt = "auipc"
        instrtxt = f"{instrtxt:<8}"
        file.write(f"\t{instrtxt}{txtrd:>3}, {u_imm:>8}\t\t# r{rd:<2} <- 0x{val:08x}, \t\t\t\t{info_txt}\n")
        total_num_instr += 1
        order += 1
    elif instr == "op_jal":
        # pick jump address up to the limit, then reverse calculate j_imm
        # only jump forwards to avoid infinite loops
        j_addr = unsigned(4*random.randint(1, jmp_limit) + pc)
        j_imm  = j_addr - pc
        garb_num = (j_addr - pc) // 4 - 1
        # execute
        write_regfile(rd, pc + 4) # according to spec
        pc = j_addr
        # print
        # print(f"jal\t{txtrd:>3}, {labeltxt:>10}\t# r{rd:<2} <- 0x{(oldpc+4):08x}, {info_txt}")
        instrtxt = "jal"
        instrtxt = f"{instrtxt:<8}"
        file.write(f"\t{instrtxt}{txtrd:>3}, {labeltxt:>10}\t\t# r{rd:<2} <- 0x{(oldpc+4):08x}, \t\t\t\t{info_txt}\n")
        total_num_instr += 1
        gen_garbage(garb_num)
        total_num_instr += garb_num
        order += 1
        # print(f"{labeltxt}:") # create label
        file.write(f"{labeltxt}:\n") # create label
        label_num += 1
    elif instr == "op_jalr":
        if not regfile_valid[rs1]:
            continue
        # use rs1 to determine set of valid jump addresses up to a limit
        # randomly choose from this set and calculate the immediate
        min_rs1_addr = unsigned(rs1_val) - 2**11
        max_rs1_addr = unsigned(rs1_val) + 2**11-1
        min_jmp_addr = pc + 4
        max_jmp_addr = pc + 4*jmp_limit
        valid = min_jmp_addr <= max_rs1_addr and min_rs1_addr <= max_jmp_addr
        if valid:
            j_addr = random.randint(max(min_jmp_addr,min_rs1_addr), min(max_rs1_addr,max_jmp_addr)) & ~3
            j_imm  = j_addr - rs1_val
            garb_num = (j_addr - pc) // 4 - 1

            # execute
            write_regfile(rd, pc + 4) # according to spec
            pc = j_addr
            # print
            instrtxt = "jalr"
            instrtxt = f"{instrtxt:<8}"
            file.write(f"\t{instrtxt}{txtrd:>3}, {j_imm:>5}({txtr1:>3})\t\t# r{rd:<2} <- 0x{(oldpc+4):08x}, \t\t\t\t{info_txt}\n")
            total_num_instr += 1
            gen_garbage(garb_num)
            total_num_instr += garb_num
            order += 1
            # file.write(f"{labeltxt}:\n") # create label
            # label_num += 1
    elif instr == "op_br":
        if not regfile_valid[rs1] or not regfile_valid[rs2]:
            continue
        br_type = random.choice(br_types)
        # pick branch address, then reverse calculate b_imm
        # only branch forwards to avoid infinite loops
        b_addr = unsigned(4*random.randint(1, jmp_limit) + pc)
        b_imm  = b_addr - pc
        garb_num = (b_addr - pc) // 4 - 1
        # execute
        br_en = comparator(br_type, rs1_val, rs2_val)

        if br_en:
            pc = pc + b_imm
        else:
            pc = pc + 4

        # print
        file.write(f"{labeltxt}:\n") # create label here, then add the b_imm
        label_num += 1
        instrtxt = f"{br_type:<8}"
        if br_en:
            file.write(f"\t{instrtxt}{txtr1:>3}, {txtr2:>3}, {labeltxt}+{b_imm:>3}\t# branch     taken,  \t\t\t\t{info_txt}\n")
            gen_garbage(garb_num)
            total_num_instr += garb_num
        else:
            # print(f"{br_type}\t{txtr1:>3}, {txtr2:>3}, {labeltxt}+{b_imm}\t# branch not taken,  {info_txt}")
            file.write(f"\t{instrtxt}{txtr1:>3}, {txtr2:>3}, {labeltxt}+{b_imm:>3}\t# branch not taken,  \t\t\t\t{info_txt}\n")
        total_num_instr += 1
        order += 1
    elif instr == "op_load":
        if not regfile_valid[rs1]:
            continue
        ld_type = random.choice(ld_types)
        # use rs1 value to determine set of valid & used addresses
        # then randomly choose from this set and calculate immediate
        min_addr = unsigned(rs1_val) - 2**11
        max_addr = unsigned(rs1_val) + 2**11-1
        valid = mem_start <= max_addr and min_addr <= mem_end-4
        addrz = list(memory.keys())
        addrz = [i for i in addrz if max(mem_start,min_addr) <= i <= min(mem_end-4,max_addr)]
        valid = valid and len(addrz) > 0
        if valid:
            ld_addr = random.choice(addrz)
            
            num_bytes = 0
            signed = True

            # align and determine sign
            if ld_type == "lb":
                num_bytes = 1
                signed = True
            elif ld_type == "lh":
                ld_addr = ld_addr & ~1
                num_bytes = 2
                signed = True
            elif ld_type == "lw":
                ld_addr = ld_addr & ~3
                num_bytes = 4
                signed = True
            elif ld_type == "lbu":
                num_bytes = 1
                signed = False
            elif ld_type == "lhu":
                ld_addr = ld_addr & ~1
                num_bytes = 2
                signed = False
            else:
                assert False, "bad load!"
        
            # reverse compute immediate
            ld_imm = ld_addr - rs1_val
            # false if out cannot be expressed as 12 bit value
            valid = (-2**11 <= ld_imm < 2**11 - 1)
            valid = valid and check_addr(ld_addr, num_bytes, read=True)

        # execute
        rdata = 0
        if valid:
            rdata = read_mem(ld_addr, num_bytes)
            if signed:
                rdata = unsigned(sign_extend(rdata, 8*num_bytes))
            else:
                rdata = unsigned(rdata)
            write_regfile(rd, rdata)
            pc = pc + 4
        
        # print
        if valid:
            # print(f"{ld_type}\t{txtrd:>3}, {imm_12:>5}({txtr1:>3})\t# r{rd:<2} <- M[0x{val:08x}], {info_txt}")
            instrtxt = f"{ld_type:<8}"     
            file.write(f"\t{instrtxt}{txtrd:>3}, {ld_imm:>5}({txtr1:>3})\t\t# r{rd:<2} <- M[0x{ld_addr:08x}](0x{rdata:08x}), {info_txt}\n")
            total_num_instr += 1
            order += 1
            load_instr_count += 1
    elif instr == "op_store":
        if not regfile_valid[rs1] or not regfile_valid[rs2]:
            continue
        st_type = random.choice(st_types)
        # use rs1 value to determine set of valid addresses
        # then randomly choose from this set and calculate immediate
        min_addr = unsigned(rs1_val) - 2**11
        max_addr = unsigned(rs1_val) + 2**11-1
        valid = mem_start <= max_addr and min_addr <= mem_end-4
        if valid:
            st_addr = random.randint(max(mem_start,min_addr), min(mem_end-4,max_addr))

            # (st_addr & 0xffffffff) - (rs1_val & 0xffffffff)
            num_bytes = 0

            # align
            if   st_type == "sb":
                num_bytes = 1
            elif st_type == "sh":
                st_addr = st_addr & ~1
                num_bytes = 2
            elif st_type == "sw":
                st_addr = st_addr & ~3
                num_bytes = 4
            else:
                assert False, "bad store!"
            
            # reverse compute immediate
            st_imm = unsigned(st_addr) - unsigned(rs1_val)
            # false if out cannot be expressed as 12 bit value
            valid = valid and (-2**11 <= st_imm < 2**11 - 1)
            # if not valid:
                # print(st_imm)
            valid = valid and check_addr(st_addr, num_bytes, read=False)

        # execute
        wdata = 0
        if valid:
            write_mem(st_addr, rs2_val, num_bytes)
            for i in range(num_bytes):
                wdata |= rs2_val & (0xff << 8*i)
            pc = pc + 4
        
        # print
        if valid:
            instrtxt = f"{st_type:<8}"
            file.write(f"\t{instrtxt}{txtr2:>3}, {st_imm:>5}({txtr1:>3})\t\t# M[0x{st_addr:08x}] <- r{rs2:<2}(0x{wdata:08x}), {info_txt}\n")
            total_num_instr += 1
            order += 1
            store_instr_count += 1
    elif instr == "op_imm":
        if not regfile_valid[rs1]:
            continue
        imm_type = random.choice(imm_types)
        instrtxt = f"{imm_type:<8}"
        if  imm_type in ["slli", "srli", "srai"]:
            shift_imm   = random.randint(0, 31)
            result = alu(imm_type[:-1], rs1_val, shift_imm)
            write_regfile(rd, result)
            pc = pc + 4

            # print
            # print(f"{imm_type}\t{txtrd:>3}, {txtr1:>3}, {shift_imm:>5}\t# r{rd:<2} <- 0x{result:08x}, {info_txt}")
            file.write(f"\t{instrtxt}{txtrd:>3}, {txtr1:>3}, {shift_imm:>5}\t\t# r{rd:<2} <- 0x{result:08x}, \t\t\t\t{info_txt}\n")
        else:
            result = 0
            if   imm_type == "slti":
                br_en = comparator("blt", rs1_val, sign_extend(imm_12,12))
                if br_en:
                    result = 1
                else:
                    result = 0
            elif imm_type == "sltiu":
                br_en = comparator("bltu", rs1_val, sign_extend(imm_12,12))
                if br_en:
                    result = 1
                else:
                    result = 0
            elif imm_type in ["addi", "xori", "ori", "andi"]:
                result = alu(imm_type[:-1], rs1_val, sign_extend(imm_12,12))
            else:
                assert False, "bad imm-reg instruction!"
            write_regfile(rd, result)
            pc = pc + 4

            # print
            # print(f"{imm_type}\t{txtrd:>3}, {txtr1:>3}, {imm_12:>5}\t# r{rd:<2} <- 0x{result:08x}, {info_txt}")
            file.write(f"\t{instrtxt}{txtrd:>3}, {txtr1:>3}, {imm_12:>5}\t\t# r{rd:<2} <- 0x{result:08x}, \t\t\t\t{info_txt}\n")
        total_num_instr += 1
        order += 1
    elif instr == "op_reg":
        if not regfile_valid[rs1] or not regfile_valid[rs2]:
            continue
        reg_type = random.choice(reg_types)
        # execute
        result = 0
    
        if reg_type == "slt":
            br_en = comparator("blt", rs1_val, rs2_val)
            if br_en:
                result = 1
            else:
                result = 0
        elif reg_type == "sltu":
            br_en = comparator("bltu", rs1_val, rs2_val)
            if br_en:
                result = 1
            else:
                result = 0
        else:
            result = alu(reg_type, rs1_val, rs2_val)
        
        write_regfile(rd, result)
        pc = pc + 4

        # print
        # print(f"{reg_type}\t{txtrd:>3}, {txtr1:>3}, {txtr2:>3}\t# r{rd:<2} <- 0x{result:08x}, {info_txt}")
        instrtxt = f"{reg_type:<8}"
        file.write(f"\t{instrtxt}{txtrd:>3}, {txtr1:>3}, {txtr2:>3}\t\t# r{rd:<2} <- 0x{result:08x}, \t\t\t\t{info_txt}\n")
        
        total_num_instr += 1
        order += 1
    elif instr == "op_muldiv":
        if not regfile_valid[rs1] or not regfile_valid[rs2]:
            continue
        # file.write(f"\t{instrtxt}{txtrd:>3}, {txtr1:>3}, {txtr2:>3}\t\t# {comment}\n")
        muldiv_type = random.choice(muldiv_types)

        result = muldiv_alu(muldiv_type, rs1_val, rs2_val)

        write_regfile(rd, result)
        pc = pc + 4

        instrtxt = f"{muldiv_type:<8}"
        file.write(f"\t{instrtxt}{txtrd:>3}, {txtr1:>3}, {txtr2:>3}\t\t# r{rd:<2} <- 0x{result:08x}, \t\t\t\t{info_txt}\n")
        total_num_instr += 1
        order += 1

    # for i in range(reg_num):
    #     print(f"# r{i:<2}: 0x{regfile[i]:08x}")

# halt instruction padding
file.write("halt:\n")
for _ in range(1):
    file.write(f"\tslti\t x0,  x0, -256\t\t# \t\t\t\t\t\t\t\t\torder=0x{order:08x}\n")

print(f"program length: {total_num_instr}")
print(f"load_instr_count = {load_instr_count}")
print(f"store_instr_count = {store_instr_count}")

for i in range(reg_num):
    print(f"r{i:<2}: 0x{regfile[i]:08x}")
print(f"total commit num: {order}")
# addrs = list(memory.keys())
# addrs.sort()
# for addr in addrs:
#     print(f"M[0x{addr:08x}] : 0x{memory[addr]:02x}")
