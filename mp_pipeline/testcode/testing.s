.section .text
.globl _start
_start:
    and     x5, x5, x0 # zero x5
    addi    x1, x0, 4
    and     x2, x2, x0 # zero x2
    addi    x3, x2, 8
    lui     x6, 13 # random lui
    auipc   x5, 0
    sw      x1, 0(x5)  # store
    or      x4, x1, x2 # data hazard?
    add     x4, x4, x4
    lw      x1, 0(x5) # load hazard
    nop
    auipc   x1, 0 # use rd consecutively
    addi    x1, x0, 4 
    addi    x2, x0, 8
    addi    x3, x0, 12
    addi    x4, x0, 16
    addi    x2, x0, 20
    addi    x1, x0, 24 # data hazard with stores later
    addi    x3, x0, 28
    sw      x1, 0(x5) # many memory operations at once
    sw      x2, 4(x5)
    lw      x2, 0(x5)
    sw      x3, 8(x5)
    lw      x3, 4(x5)
    sh      x4, 14(x5) # store half to the upper two bytes
    lw      x4, 8(x5)
    lw      x4, 12(x5) # now load the full word back, expecting the upper half back
    lb      x6, 1(x5)
    lb      x7, 3(x5)
    lb      x8, 5(x5)
    sb      x1, 1(x5)
    sb      x3, 13(x5)
    lbu     x6, 1(x5)
    lbu     x7, 3(x5)
    lhu     x8, 6(x5)
    sb      x1, 1(x5)
    sh      x3, 14(x5)
    addi    x6, x5, 1 # try off-aligned address
    sw      x1, -1(x6)
    sh      x2, 5(x6)
    sb      x3, 0(x6)
    lw      x1, -1(x6)
    lh      x1, 1(x6)
    lhu     x1, 5(x6)
    lbu     x1, 3(x6)
    lb      x1, 2(x6)
    add     x1, x2, x3 # mix of both types of instructions
    and     x1, x2, x3
    lw      x1, 0(x5)
    or      x1, x2, x3
    lhu     x1, 2(x5)
    addi    x1, x2, 17
    auipc   x1, 0       # data hazard mayhem
    sw      x1, 0(x1)
    lw      x1, 4(x1)
    addi    x2, x0, 8
    addi    x1, x2, 1
    or      x2, x1, x2
    auipc   x1, 0
    lw      x3, -24(x1) # load hazard
    nop
    sw      x3, -20(x1)
    lw      x1, 0(x3)   # load hazard
    nop
    addi    x2, x1, 0
    and     x4, x1, x2
    and     x1, x4, x2
    and     x2, x1, x4
    addi    x1, x2, 19
    lw      x1, 0(x3)   # load hazard
    nop
    and     x1, x1, x2
# must save regfile readout here
    auipc   x1, 0       
    sw      x1, 0(x1)
    addi    x2, x0, 5
    lw      x3, 0(x1)   # load hazard
    nop
    add     x4, x3, x1
    
    and     x1, x1, x0
    addi    x1, x1, 3
    addi    x4, x0, 14  # initialize x4 to 14
    bne     x0, x0, branch # try a branch
branch:
    addi    x2, x0, 7
    addi    x1, x1, 1   # increment x1
    bne     x1, x4, branch # loop 14 times
    addi    x4, x4, 1   # control hazards
    andi    x2, x2, 2
    auipc   x1, 12
    jal     x1, branch1 # some unconditional jumps
    addi    x1, x1, 7
    jal     x0, branch2 # skip me!
branch1:
    addi    x2, x0, 13
    addi    x4, x0, 17
    addi    x5, x0, 15
branch2:
    sw      x2, 0(x3) # store 13 to 0(x3)
    lw      x1, 0(x3) # load 13 to x1
    blt     x1, x2, branch4 # compare 13 vs 13, don't branch tho    
    lw      x6, 0(x3) # do this
    bge     x4, x2, branch4 # compare 17 vs 13, branch!
    lw      x3, 0(x3)   # don't do these
    and     x3, x0, x3
branch4:
    addi    x3, x3, 4   # try a data hazard with the untaken branch
    sw      x5, 0(x3)   # store 15 to 0(x3)
    lw      x1, 0(x3)   # load 15 to x1
    lw      x1, -4(x3)  # load 13 to x1
    # many consecutive branches
    jal     x0, branch5 # unconditional branch
    jal     x0, branch6 # dont do this
branch5:
    jal     x0, branch7 # do this
branch6:
    jal     x0, branch5 # dont do this
branch7:
    andi    x1, x1, 0   # do this
# loading right after a branch
    jal     x0, branch8 # branch and invalidate the following loads
    lw      x1, 0(x3)   # dont do this
    sw      x0, 0(x3)   # dont do this
branch8:
    lw      x2, -4(x3)
    sw      x2, -4(x3)

    
    # python generated
srai x16, x7, 15
srli x17, x28, 0
srai x25, x15, 27
add x21, x2, x8
sw x21, 100(x8)
add x31, x3, x7
add x30, x7, x30
or x26, x25, x6
addi x1, x21, 59
ori x30, x4, 41
sub x30, x23, x13
ori x7, x2, 1
and x8, x7, x8
xori x19, x26, 85
xori x27, x11, 45
andi x31, x24, 99
xor x18, x24, x1
addi x8, x27, 37
sll x18, x11, x20
add x8, x18, x6
xori x2, x13, 59
sll x19, x8, x24
sub x11, x8, x5
addi x6, x11, 1
srl x3, x18, x11
xor x19, x6, x4
xori x15, x6, 3
andi x24, x27, 84
sw x6, 236(x9)
and x8, x4, x17
and x11, x6, x26
addi x25, x7, 1
addi x12, x10, 36
or x24, x8, 50
andi x10, x30, 31
sra x15, x11, x6
xori x21, x17, 84
andi x2, x4, 59
srai x28, x18, 12
sra x30, x15, x30
slli x8, x31, 17
slli x30, x1, 7
srai x18, x18, 7
add x16, x2, x20
sub x12, x4, x25
srai x31, x5, 29
sll x31, x24, x10
addi x17, x18, 16
addi x27, x13, 47
or x20, x16, 31
add x17, x25, x17
or x12, x30, 32
xor x11, x12, 36
addi x15, x5, 19
sub x29, x5, x9
srl x6, x4, x28
sll x12, x11, x24
sw x9, 308(x11)
addi x7, x21, 34
xor x19, x15, 29
or x14, x23, 19
add x24, x9, x11
ori x12, x10, 30
and x14, x16, x20
sub x5, x13, x23
sll x29, x6, x30
xori x21, x6, 22
xor x23, x16, x29
srl x3, x14, x8
add x11, x14, x26
or x18, x17, x19
srai x7, x2, 18
srli x13, x14, 7
xor x26, x8, x10
srl x7, x2, x21
and x6, x23, x24
sra x13, x2, x23
add x13, x28, x23
or x14, x1, x27
ori x29, x16, 31
or x4, x16, 13
addi x12, x10, 16
addi x20, x6, 12
srl x8, x12, x23
or x4, x5, x6
and x9, x27, x7
andi x5, x8, 89
addi x2, x31, 31
xor x27, x23, 18
or x31, x29, 35
sra x24, x19, x3
xor x27, x29, x6
and x23, x21, x1
sll x31, x29, x5
addi x5, x14, 49
and x24, x7, x24
and x5, x29, x30
srai x21, x13, 7
and x1, x15, x24
and x14, x4, x6
and x29, x1, x21
sub x30, x3, x18
slli x25, x22, 2
xori x17, x17, 90
ori x30, x21, 97
and x22, x24, x16
sub x10, x14, x14
ori x23, x24, 97
xor x3, x12, x24
xor x16, x28, x8
and x16, x4, x13
sra x3, x25, x18
sub x15, x9, x19
sra x7, x27, x2
srai x25, x8, 8
sub x18, x30, x17
or x12, x30, x20
sw x21, 24(x20)
addi x19, x2, 52
or x7, x14, x11
xor x15, x2, x10
ori x26, x12, 21
sub x18, x13, x3
and x2, x16, x16
sub x27, x22, x24
sub x7, x30, x21
sra x30, x30, x5
srli x14, x28, 4
add x30, x2, x3
or x10, x21, x9
xori x1, x23, 45
slli x6, x5, 20
ori x24, x20, 32
sra x23, x3, x18
srai x16, x28, 9
sll x18, x4, x31
auipc x22, 0
lw x9, 288(x22)
xor x31, x14, 47
xor x6, x10, 29
xor x13, x19, 18
auipc x18, 0
lw x11, 248(x18)
xor x4, x4, 4
addi x7, x12, 18
or x24, x29, 7
slli x14, x20, 5
or x21, x26, x11
srli x5, x24, 5
ori x1, x26, 34
srli x31, x30, 14
or x23, x8, x30
auipc x1, 0
lw x5, 216(x1)
xor x7, x22, 33
addi x5, x3, 19
xor x29, x4, 37
andi x9, x12, 61
slli x10, x17, 19
andi x13, x13, 27
xor x31, x16, x6
sll x15, x26, x21
srai x31, x11, 19
or x27, x11, x30
xori x28, x13, 8
srli x10, x5, 11
srli x7, x10, 1
xor x4, x20, x30
xori x15, x22, 92
sra x4, x3, x12
auipc x29, 0
lw x4, 220(x29)
or x30, x2, 24
xor x11, x7, 38
or x26, x31, 11
addi x21, x6, 67
xori x6, x11, 75
sll x1, x17, x8
auipc x18, 0
lw x12, 324(x18)
addi x16, x22, 27
addi x16, x13, 30
addi x15, x13, 35
addi x25, x19, 80
sll x13, x28, x5
slli x1, x20, 8
xor x6, x18, x7
srli x25, x26, 5
auipc x26, 0
lw x4, 392(x26)
xor x19, x30, 13
xor x25, x31, 15
or x5, x30, 15
addi x21, x27, 57
ori x7, x22, 46
srai x5, x12, 20
andi x14, x3, 18
sra x13, x2, x20
srli x4, x21, 1
slli x11, x3, 13
add x10, x24, x27
xor x26, x19, x28
srl x9, x21, x6
sll x15, x8, x4
andi x1, x13, 9
sw x24, 244(x9)
andi x24, x14, 34
andi x2, x6, 40
sw x5, 384(x31)
auipc x28, 0
lw x18, 152(x28)
addi x11, x25, 41
xor x29, x3, 27
xor x17, x3, 26
auipc x21, 0
lw x22, 192(x21)
xor x7, x26, 30
addi x25, x10, 40
or x20, x26, 41
sll x13, x28, x27
addi x12, x10, 73
srl x10, x14, x27
slli x18, x9, 6
sub x27, x1, x20
xor x8, x12, x13
andi x12, x30, 30
sw x27, 372(x11)
andi x8, x13, 1
sra x10, x2, x30
srli x15, x6, 21
xori x23, x1, 56
and x23, x14, x20
srl x14, x6, x20

    slti    x0, x0, -256 # this is the magic instruction to end the simulation
