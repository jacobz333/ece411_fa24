memory.s:
.align 4
.section .data
.globl my_data

my_data:
.word   0x01234567
.word   0x89abcdef
.word   0xdeadbeef
.word   0xeceb2022
.word   0x00ece411

.section .text
.globl _start
_start:
    la  x1, my_data

halt:
    slti x0, x0, -256
