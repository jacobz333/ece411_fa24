#!/bin/bash

cd ../sim
make clean
make run_vcs_top_tb PROG=../testcode/ooo_test_ls_only.s
cd ../scripts 
