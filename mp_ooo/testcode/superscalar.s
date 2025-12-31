superscalar.s:
.align 4
.section .text
.globl _start
    # This program will test superscalar effectiveness
    # It ensures that instructions are loaded to cache,
    # meaning instruction fetch is not a bottleneck
_start:
# initialize
li  x22, 100
_branch:
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
lui x14, 356
lui x15, 356
lui x16, 356
lui x17, 356
lui x18, 356
lui x19, 356
lui x20, 356
lui x21, 356
lui x23, 356
lui x24, 356
lui x25, 356
lui x26, 356
lui x27, 356
addi x22, x22, -1
bnez x22, _branch
slti x0, x0, -256
