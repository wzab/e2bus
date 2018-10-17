#!/bin/bash
IP_DIR=../src/atlys/ip_atlys
(
  cd ${IP_DIR}
  for ip in \
    cmd_ack_fifo \
    cmd_frm_dpr \
    resp_ack_dpr \
    cmd_desc_dpr \
    dcm1 \
    resp_dpr \
    ; do coregen -r -b ${ip}.xco -p coregen.cgp ;
  done
)
xtclsh e2bus_atlys.tcl rebuild_project
