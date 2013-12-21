#!/bin/bash

set -e

if [ $# -eq 0 ]
then
    echo "Usage: diskcheck.sh DEVICE..."
    exit 1
fi

function smartcheck {
    local disk=$1
    local check_no=$2
    local basename=$(basename $disk)
    smartctl -d sat --all $disk > ${basename}.smart.${check_no}
}

function checkdisk {
    local disk=$1
    local basename=$(basename ${disk})
    smartcheck $disk 1
    badblocks -sv -o ${basename}.bb.ro ${disk}
    smartcheck $disk 2
    badblocks -svw -o ${basename}.bb.rw ${disk}
    smartcheck $disk 3
    zcav $disk > ${basename}.zcav
    smartcheck $disk 4
}

for disk in "$@"
do
    checkdisk $disk
done