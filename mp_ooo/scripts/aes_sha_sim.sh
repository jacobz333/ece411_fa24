#!/bin/bash

cd ../sim
make clean
make run_vcs_top_tb PROG=../testcode/cp3_release_benches/aes_sha.elf
make spike ELF=../testcode/cp3_release_benches/aes_sha.elf
diff -s spike/spike.log spike/commit.log | head -n 20
cd ../scripts 