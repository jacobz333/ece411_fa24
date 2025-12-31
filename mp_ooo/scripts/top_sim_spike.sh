#!/bin/bash
cd ../sim
make clean
make run_vcs_top_tb PROG=../testcode/simple_branch.s
cd ../scripts
cd ../sim
make spike ELF=./bin/simple_branch.elf
# show first 20 lines that are different
diff -s spike/spike.log spike/commit.log | head -n 20
cd ../scripts 
