#!/bin/bash
cd ../testcode
python3 python_testbench.py
cd ../sim
# make clean
make vcs/top_tb PROG=../testcode/python_test.s
make run_vcs_top_tb PROG=../testcode/python_test.s
cd ../scripts
cd ../sim
make spike ELF=./bin/python_test.elf
# show first 20 lines that are different
diff -s spike/spike.log spike/commit.log | head -n 20
cd ../scripts 
