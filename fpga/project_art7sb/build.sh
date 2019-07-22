#!/bin/bash
set -e
git submodule update --init --recursive
(
  cd ../extbus
  ./gener_slaves.sh
)
vivado -mode batch -source eprj_create.tcl
vivado -mode batch -source eprj_write.tcl
vivado -mode batch -source eprj_build.tcl
