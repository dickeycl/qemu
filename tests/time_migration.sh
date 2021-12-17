#!/bin/bash

# 
# Script to measure delta save speed during a migration.
#
# This times one migration.
#
# The workload, SRC_IMAGE,provided by Moshik Hershcovitz, is a 5-minute long
# python task.
# Results are written to mig_report.

function qgd() {
  qemu-img create -f qcow2 $IMAGE 10G
  rm -f $MIGRATION
  python3 -c "import socket as s; s.socket(s.AF_UNIX).bind('$MIGRATION')"
  SOCKET=/tmp/qemu_monitor_d
  rm -f $SOCKET
  $QEMU_INSTALL/bin/qemu-system-x86_64 \
    -drive file=$IMAGE,if=virtio \
    -m $MEMORY \
    -accel kvm \
    -msg timestamp=on \
    -incoming unix:$MIGRATION \
    -monitor unix:$SOCKET,server,wait=off &
  QEMU_PID=$!
  trap "kill $QEMU_PID" EXIT
  sleep 5

  {
    sleep 400 # long enough for a 5-minute python task, and migration, to finish
    echo quit
  } | nc -U "$SOCKET"
}

function qgs() {
  cp $IMAGE.orig $IMAGE
  SOCKET=/tmp/qemu_monitor_s
  rm -f $SOCKET
  python3 -c "import socket as s; s.socket(s.AF_UNIX).bind('$SOCKET')"
  $QEMU_INSTALL/bin/qemu-system-x86_64 \
    -drive file=$IMAGE,if=virtio \
    -m $MEMORY \
    -accel kvm \
    -msg timestamp=on \
    -monitor unix:$SOCKET,server,wait=off &
  QEMU_PID=$!
  trap "kill $QEMU_PID" EXIT
  sleep 5

  {
    echo log trace:savevm_section_start
    echo log trace:savevm_section_end
    echo log trace:ram_pages_saved
    echo log trace:qemu_file_fclose
    sleep 60
    echo migrate_set_capability auto-converge on
    echo migrate unix:$MIGRATION
    echo quit
  } | nc -U "$SOCKET"
} 2>&1 > /dev/tty

set -eu

HOME=/home/clem
# uses scripts/monprocess.py from the QEMU source
QEMU_SOURCE=$HOME/j10
# uses bin/qemu-system-x86_64 from the QEMU build
QEMU_INSTALL=$HOME/q

SRC_IMAGE=/home/clem/photon-py-5min_data1GB_bench4.qcow2
DST_IMAGE=/tmp/destdisk1.qcow2
MEMORY=4G
MIGRATION=/tmp/qemu_migration

QEMU_INSTALL=$QEMU_INSTALL IMAGE=$DST_IMAGE MEMORY=$MEMORY MIGRATION=$MIGRATION qgd &
DEST_PID=$!
QEMU_INSTALL=$QEMU_INSTALL IMAGE=$SRC_IMAGE MEMORY=$MEMORY MIGRATION=$MIGRATION qgs | $QEMU_SOURCE/scripts/monprocess.py > mig_report
wait $DEST_PID
