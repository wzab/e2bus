#!/bin/bash
set -e
#mkdir -p ../sw
mkdir -p wb_gener
#./addr_gen_wb/src/addr_gen_wb.py --infile system.xml --hdl wb_gener --header ../sw --ipbus ../sw --fs ../fw
./addr_gen_wb/src/addr_gen_wb.py --infile system.xml --hdl wb_gener
