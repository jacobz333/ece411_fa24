#!/bin/bash

cd ../sim
make clean
make run_vcs_top_tb PROG=../testcode/ooo_test.s
cd ../scripts 
