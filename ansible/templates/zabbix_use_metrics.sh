#!/bin/bash

case $1 in
    "cpu_util")
        grep '^cpu ' /proc/stat | awk '{print ($2+$4)*100/($2+$4+$5)}'
        ;;
    "cpu_sat")
        vmstat 1 2 | tail -1 | awk '{print $1}'
        ;;
    "memory_util")
        free | grep Mem | awk '{print $3/$2 * 100.0}'
        ;;
    "memory_sat")
        awk '{print $2}' /proc/pressure/memory 2>/dev/null | cut -d= -f2 | cut -d" " -f1 || echo 0
        ;;
    "disk_util")
        df "$2" | tail -1 | awk '{print $5}' | sed 's/%//'
        ;;
    "disk_sat")
        iostat -x 1 2 2>/dev/null | grep "$2" | tail -1 | awk '{print $12}' || echo 0
        ;;
esac