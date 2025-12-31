#!/bin/bash

cd ../sim
make clean
make run_vcs_top_tb PROG=../testcode/additional_testcases/compression.elf
make spike ELF=../testcode/additional_testcases/compression.elf
diff -s spike/spike.log spike/commit.log | head -n 20
cd ../scripts 
