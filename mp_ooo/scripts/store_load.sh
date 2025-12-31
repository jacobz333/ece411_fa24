#!/bin/bash
cd ../sim
make clean
make run_vcs_top_tb PROG=../testcode/store_load.s
cd ../scripts
cd ../sim
make spike ELF=./bin/store_load.elf
diff -s spike/spike.log spike/commit.log | head -n 20
cd ../scripts 
