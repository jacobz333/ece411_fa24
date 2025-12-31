ooo_test.s:
.align 4
.section .text
.globl _start
    # This program will provide a simple test for
    # demonstrating OOO-ness
    # This test is NOT exhaustive
_start:
# initialize
lui x1 , 832
lui x2 , 21
lui x3 , 123
lui x4 , 751
lui x5 , 928
lui x6 , 315
lui x7 , 815
lui x8 , 235
lui x9 , 51
lui x10, 231
lui x11, 251
lui x12, 951
lui x13, 356
lui x14, 712
lui x15, 101
lui x16, 811
lui x17, 413
lui x18, 292
lui x19, 987
lui x20, 231
lui x21, 251
lui x22, 92
lui x23, 356
lui x24, 812
lui x25, 100
lui x26, 11
lui x27, 871
lui x28, 292
lui x29, 987
lui x30, 112

nop
nop
nop
nop
nop
nop



sw x1 , 0(x1 )
sw x2 , 0(x2 )
sw x3 , 0(x3 )
sw x4 , 0(x4 )
sw x5 , 0(x5 )
sw x6 , 0(x6 )
sw x7 , 0(x7 )
sw x8 , 0(x8 )
sw x9 , 0(x9 )
sw x10, 0(x10)
sw x11, 0(x11)
sw x12, 0(x12)
sw x13, 0(x13)
sw x14, 0(x14)
sw x15, 0(x15)
sw x16, 0(x16)
sw x17, 0(x17)
sw x18, 0(x18)
sw x19, 0(x19)
sw x20, 0(x20)
sw x21, 0(x21)
sw x22, 0(x22)
sw x23, 0(x23)
sw x24, 0(x24)
sw x25, 0(x25)
sw x26, 0(x26)
sw x27, 0(x27)
sw x28, 0(x28)
sw x29, 0(x29)
sw x30, 0(x30)

addi x1 , x1 , 0x400 
addi x2 , x2 , 0x400 
addi x3 , x3 , 0x400 
addi x4 , x4 , 0x400 
addi x5 , x5 , 0x400 
addi x6 , x6 , 0x400 
addi x7 , x7 , 0x400 
addi x8 , x8 , 0x400 
addi x9 , x9 , 0x400 
addi x10, x10, 0x400 
addi x11, x11, 0x400 
addi x12, x12, 0x400 
addi x13, x13, 0x400 
addi x14, x14, 0x400 
addi x15, x15, 0x400 
addi x16, x16, 0x400 
addi x17, x17, 0x400 
addi x18, x18, 0x400 
addi x19, x19, 0x400 
addi x20, x20, 0x400 
addi x21, x21, 0x400 
addi x22, x22, 0x400 
addi x23, x23, 0x400 
addi x24, x24, 0x400 
addi x25, x25, 0x400 
addi x26, x26, 0x400 
addi x27, x27, 0x400 
addi x28, x28, 0x400 
addi x29, x29, 0x400 
addi x30, x30, 0x400 

sw x1 , 0(x1 )
sw x2 , 0(x2 )
sw x3 , 0(x3 )
sw x4 , 0(x4 )
sw x5 , 0(x5 )
sw x6 , 0(x6 )
sw x7 , 0(x7 )
sw x8 , 0(x8 )
sw x9 , 0(x9 )
sw x10, 0(x10)
sw x11, 0(x11)
sw x12, 0(x12)
sw x13, 0(x13)
sw x14, 0(x14)
sw x15, 0(x15)
sw x16, 0(x16)
sw x17, 0(x17)
sw x18, 0(x18)
sw x19, 0(x19)
sw x20, 0(x20)
sw x21, 0(x21)
sw x22, 0(x22)
sw x23, 0(x23)
sw x24, 0(x24)
sw x25, 0(x25)
sw x26, 0(x26)
sw x27, 0(x27)
sw x28, 0(x28)
sw x29, 0(x29)
sw x30, 0(x30)

lw x1 , 0(x2 )
lw x2 , 0(x3 )
lw x3 , 0(x4 )
lw x4 , 0(x5 )
lw x5 , 0(x6 )
lw x6 , 0(x7 )
lw x7 , 0(x8 )
lw x8 , 0(x9 )
lw x9 , 0(x10)
lw x10, 0(x11)
lw x11, 0(x12)
lw x12, 0(x13)
lw x13, 0(x14)
lw x14, 0(x15)
lw x15, 0(x16)
lw x16, 0(x17)
lw x17, 0(x18)
lw x18, 0(x19)
lw x19, 0(x20)
lw x20, 0(x21)
lw x21, 0(x22)
lw x22, 0(x23)
lw x23, 0(x24)
lw x24, 0(x25)
lw x25, 0(x26)
lw x26, 0(x27)
lw x27, 0(x28)
lw x28, 0(x29)
lw x29, 0(x30)

#li x1 , 51
#li x2 , 253
#li x3 , 35
#li x4 , 953
#li x5 , 2
#li x6 , 321
#li x7 , 214
#li x8 , 243
#li x9 , 5
#li x10, 983
#li x11, 23
#li x12, 233
#li x13, 312
#li x14, 251
#li x15, 185
#li x16, 875
#li x17, 327
#li x18, 234
#li x19, 571
#li x20, 173
#li x21, 1
#li x22, 132
#li x23, 412
#li x24, 412
#li x25, 341
#li x26, 924
#li x27, 314
#li x28, 512
#li x29, 172
#li x30, 123
#
#
#nop
#nop
#nop
#nop
#nop
#nop
#
#
#
#sb x1 , 0(x1 )
#sb x2 , 0(x2 )
#sb x3 , 0(x3 )
#sb x4 , 0(x4 )
#sb x5 , 0(x5 )
#sb x6 , 0(x6 )
#sb x7 , 0(x7 )
#sb x8 , 0(x8 )
#sb x9 , 0(x9 )
#sb x10, 0(x10)
#sb x11, 0(x11)
#sb x12, 0(x12)
#sb x13, 0(x13)
#sb x14, 0(x14)
#sb x15, 0(x15)
#sb x16, 0(x16)
#sb x17, 0(x17)
#sb x18, 0(x18)
#sb x19, 0(x19)
#sb x20, 0(x20)
#sb x21, 0(x21)
#sb x22, 0(x22)
#sb x23, 0(x23)
#sb x24, 0(x24)
#sb x25, 0(x25)
#sb x26, 0(x26)
#sb x27, 0(x27)
#sb x28, 0(x28)
#sb x29, 0(x29)
#sb x30, 0(x30)
#
#lb x1 , 0(x2 )
#lb x2 , 0(x3 )
#lb x3 , 0(x4 )
#lb x4 , 0(x5 )
#lb x5 , 0(x6 )
#lb x6 , 0(x7 )
#lb x7 , 0(x8 )
#lb x8 , 0(x9 )
#lb x9 , 0(x10)
#lb x10, 0(x11)
#lb x11, 0(x12)
#lb x12, 0(x13)
#lb x13, 0(x14)
#lb x14, 0(x15)
#lb x15, 0(x16)
#lb x16, 0(x17)
#lb x17, 0(x18)
#lb x18, 0(x19)
#lb x19, 0(x20)
#lb x20, 0(x21)
#lb x21, 0(x22)
#lb x22, 0(x23)
#lb x23, 0(x24)
#lb x24, 0(x25)
#lb x25, 0(x26)
#lb x26, 0(x27)
#lb x27, 0(x28)
#lb x28, 0(x29)
#lb x29, 0(x30)

# this should take many cycles
# if this writes back to the ROB after the following instructions, you get credit for CP2

# RAW
mul x3, x1, x2
add x5, x3, x4

# WAW
mul x6, x7, x8
add x6, x9, x10

# WAR
mul x11, x12, x13
add x12, x1, x2

add x4, x5, x6
xor x7, x8, x9
sll x10, x11, x12
and x13, x14, x15
and     x5, x5, x0  # zero x5
addi    x1, x0, 4
and     x2, x2, x0  # zero x2
addi    x3, x2, 8
lui     x6, 13      # random lui
auipc   x22, 88
or      x4, x1, x2  # data hazard
add     x4, x4, x4
addi    x1, x0, 4   # bunch of data hazards
addi    x2, x1, 8
addi    x3, x2, 12
bne     x1, x1, halt
addi    x2, x1, 8
addi    x3, x2, 12
beq     x0, x0, skip
addi    x4, x2, 16
addi    x2, x3, 20
addi    x1, x1, 24
addi    x3, x2, 28

skip: 
add     x4, x4, x4
addi    x1, x0, 4  
addi    x2, x1, 8
addi    x3, x2, 12

jal     x4, jaltest
# skip form here 
add x4, x5, x6
xor x7, x8, x9
sll x10, x11, x12
and x13, x14, x15
and     x6, x6, x0 
addi    x1, x0, 4
and     x2, x2, x0 
addi    x3, x2, 8
lui     x6, 13     
auipc   x22, 88
or      x4, x1, x2  
add     x4, x4, x4
addi    x1, x0, 4   
addi    x2, x1, 8
addi    x3, x2, 12
bne     x1, x1, halt
addi    x2, x1, 8
addi    x3, x2, 12
beq     x0, x0, skip
addi    x4, x2, 16
addi    x2, x3, 20
addi    x1, x1, 24
addi    x3, x2, 28
add     x4, x4, x4
addi    x1, x0, 4  
addi    x2, x1, 8
addi    x3, x2, 12

jaltest:
li      x2, 31
loop: 
addi    x1, x0, 4  
addi    x5, x1, 8
addi    x3, x2, 12
srli    x2, x2, 1
bne     x0, x2, loop

halt:
    slti x0, x0, -256

and x13, x14, x15
and     x5, x5, x0  # zero x5
addi    x1, x0, 4
and     x2, x2, x0  # zero x2
addi    x3, x2, 8
lui     x6, 13      # random lui