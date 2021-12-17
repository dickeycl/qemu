#!/bin/bash

# 
# Script to measure snapshot speed
#
# This times several snapshots.
#
# The workload, SRC_IMAGE,provided by Moshik Hershcovitz, is a 5-minute long
# python task.
# Results are written to snap_report.
#
# This script uses execute, not human commands directly. There's no good
# reason for that; just trying a different method.

human() {
  echo { \"execute\": \"human-monitor-command\", \"arguments\": { \"command-line\": \"$*\" } }
}

function t() {
  $QEMU_INSTALL/bin/qemu-system-x86_64 \
    -drive file=$IMAGE,if=virtio \
    -m $MEMORY \
    -accel kvm \
    -msg timestamp=on \
    -chardev socket,id=qmp,port=4444,host=localhost,server=on \
    -mon chardev=qmp,mode=control,pretty=on &
  QEMU_PID=$!
  trap "kill $QEMU_PID" EXIT

  sleep 5

  {
    echo '{ "execute": "qmp_capabilities" }'
    human info block
    human log trace:savevm_section_start
    human log trace:savevm_section_end
    human log trace:ram_pages_saved
    human log trace:qemu_file_fclose
    for i in $(seq $((RUN_SECONDS/SAVE_INTERVAL_SECONDS)))
    do :
      sleep $SAVE_INTERVAL_SECONDS
      human savevm tag

    done
    human quit
  } | telnet localhost 4444
  wait $QEMU_PID
} 2>&1 > /dev/null

set -eu

HOME=/home/clem
# uses scripts/monprocess.py from the QEMU source
QEMU_SOURCE=$HOME/j10
# uses bin/qemu-system-x86_64 from the QEMU build
QEMU_INSTALL=$HOME/q

IMAGE=/home/clem/photon-py-5min_data1GB_bench4.qcow2
MEMORY=4G
SAVE_INTERVAL_SECONDS=1
RUN_SECONDS=30

QEMU_INSTALL=$QEMU_INSTALL SAVE_INTERVAL_SECONDS=$SAVE_INTERVAL_SECONDS RUN_SECONDS=$RUN_SECONDS MEMORY=$MEMORY IMAGE=$IMAGE t | $QEMU_SOURCE/scripts/monprocess.py > snap_report
