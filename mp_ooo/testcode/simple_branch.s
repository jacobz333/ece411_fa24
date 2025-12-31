ooo_test.s:
.align 4
.section .text
.globl _start
    
_start:
    # initialize
    li x1 , 1
    li x2 , 2
    li x3 , 3
    jal x4 , try_label
    jal x4 , _start
    jal x4 , _start
    li x3 , 100

try_label:
    add x5, x3, x3

halt:
    slti x0, x0, -256
