#!/bin/bash

cd ../sim
make clean
make run_vcs_n_cacheline_adapter_tb PROG=../testcode/memory.s
cd ../scripts
