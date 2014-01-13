#!/bin/bash

set -e

if [ $# -eq 0 ]; then
    echo 'Usage: diskcheck.sh DEVICE...' >&2
    exit 1
fi

function checkdeps {
    local deps_unmet=false
    for dep in badblocks smartctl zcav; do
        if ! which $dep &> /dev/null; then
            echo "${dep} is not installed" >&2
            deps_unmet=true
        fi
    done
    if $deps_unmet; then
        echo -e "\nUnmet dependencies, exiting..." >&2
        exit 1
    fi
}

function log {
    echo "[$(date +%c)] $@"
}

function smartcheck {
    local check_no=$1
    shift
    set +e
    for disk in $@; do
        local basename=$(basename $disk)
        log "Running SMART check #${check_no} on ${disk}"
        smartctl -d sat --all $disk > ${basename}.smart.${check_no}
        smartstat=$?
        if [ $(($smartstat & 191)) -ne 0 ]; then
            exit $smartstat
        fi
    done
    set -e
}

function bbcheck {
    local mode=$1
    shift
    test $mode = "rw" && local opt="-w" || local opt=""
    for disk in $@; do
        local basename=$(basename $disk)
        log "Checking $disk for bad blocks ($mode mode)"
        badblocks ${opt} -o ${basename}.bb.${mode} ${disk}&
    done
    wait
}

function zcavcheck {
    for disk in $@; do
        local basename=$(basename $disk)
        log "Running zcav on ${disk}"
        zcav -l ${basename}.zcav ${disk}
    done
}

function draw_zcav {
    cat <<EOF > gnuplot.gp
unset autoscale x
set autoscale xmax
set autoscale xmin
unset autoscale y
set autoscale ymax
set autoscale ymin
set xlabel "position (MB)"
set ylabel "transfer rate (MB/s)"
set terminal png size 2560,960
set output disk.".zcav.png"
set multiplot layout 1,2 title disk
set title "ro"
plot disk.".zcav.ro" pt 1 ps 1
set title "rw"
plot disk.".zcav.rw" pt 1 ps 1
unset multiplot
EOF
    for disk in $@; do
        local basename=$(basename $disk)
        which gnuplot &> /dev/null && gnuplot -e "disk='${basename}'" gnuplot.gp
    done
}

checkdeps

BASEDIR="diskcheck-$(date +%FT%T)"; mkdir $BASEDIR
pushd $BASEDIR
log "Starting diskcheck on $@"
smartcheck 1 "$@"
bbcheck ro "$@"
smartcheck 2 "$@"
bbcheck rw "$@"
smartcheck 3 "$@"
zcavcheck "$@"
smartcheck 4 "$@"
draw_zcav "$@"
log "Finished diskcheck"
popd
