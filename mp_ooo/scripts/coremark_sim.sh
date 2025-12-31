#!/bin/bash

cd ../sim
make clean
make run_vcs_top_tb PROG=../testcode/coremark_im.elf
make spike ELF=../testcode/coremark_im.elf
diff -s spike/spike.log spike/commit.log | head -n 20
cd ../scripts 
