#!/bin/sh
export BOCHS_PATH=$(dirname `which $0`)
basedir=`cd $(dirname $0); pwd -P`
export SRC_PATH=$(dirname $basedir)

gdb -x $BOCHS_PATH/gdb-cmd.txt $SRC_PATH/linux-0.12/tools/system

