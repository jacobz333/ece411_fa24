superscalar.s:
.align 4
.section .text
.globl _start
    # This program will test superscalar effectiveness
    # It ensures that instructions are loaded to cache,
    # meaning instruction fetch is not a bottleneck
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

lw x1 , 0(x1 )
lw x2 , 0(x2 )
lw x3 , 0(x3 )
lw x4 , 0(x4 )
lw x5 , 0(x5 )
lw x6 , 0(x6 )
lw x7 , 0(x7 )
lw x8 , 0(x8 )
lw x9 , 0(x9 )
lw x10, 0(x10)
lw x11, 0(x11)
lw x12, 0(x12)
lw x13, 0(x13)
lw x14, 0(x14)
lw x15, 0(x15)
lw x16, 0(x16)
lw x17, 0(x17)
lw x18, 0(x18)
lw x19, 0(x19)
lw x20, 0(x20)
lw x21, 0(x21)
lw x22, 0(x22)
lw x23, 0(x23)
lw x24, 0(x24)
lw x25, 0(x25)
lw x26, 0(x26)
lw x27, 0(x27)
lw x28, 0(x28)
lw x29, 0(x29)
lw x30, 0(x30)

halt:
    slti x0, x0, -256
