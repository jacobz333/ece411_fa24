#!/bin/bash

cd ../sim
make clean
make run_vcs_top_tb PROG=../testcode/simple_branch.s
cd ../scripts 
