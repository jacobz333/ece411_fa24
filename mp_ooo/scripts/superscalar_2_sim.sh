#!/bin/bash
cd ../sim
make clean
make run_vcs_top_tb PROG=../testcode/superscalar_2.s
cd ../scripts
cd ../sim
make spike ELF=./bin/superscalar_2.elf
diff -s spike/spike.log spike/commit.log | head -n 20
cd ../scripts 
