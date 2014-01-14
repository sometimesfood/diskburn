#!/bin/bash

checkusage() {
    [[ $# -eq 0 ]] && err_exit 'Usage: diskcheck.sh DEVICE...'
}

checkperms() {
    for disk in $@; do
        local f="diskcheck.sh: ${disk}"
        [[ -e ${disk} ]] || err_exit "${f}: No such file or directory"
        [[ -b ${disk} ]] || err_exit "${f}: Not a block device"
        [[ -r ${disk} && -w ${disk} ]] || err_exit "${f}: Permission denied"
    done
}

checkdeps() {
    local deps_unmet=false
    for dep in badblocks smartctl zcav; do
        if ! hash ${dep} >/dev/null 2>&1; then
            err "${dep} is not installed"
            deps_unmet=true
        fi
    done
    ${deps_unmet} && err_exit "\nUnmet dependencies, exiting..."
}

log() { echo -e "[$(date +%c)] $@"; }

err() { echo -e "$@" >&2; }

err_exit() {
    err "$@"
    exit 1
}

smartcheck() {
    local check_no=$1
    shift
    for disk in $@; do
        local basename=$(basename ${disk})
        log "Running SMART check #${check_no} on ${disk}"
        smartctl -d sat --all ${disk} > ${basename}.smart.${check_no}
    done
}

bbcheck() {
    local mode=$1
    shift
    [[ ${mode} = "rw" ]] && local opt="-w" || local opt=""
    for disk in $@; do
        local basename=$(basename ${disk})
        log "Checking ${disk} for bad blocks (${mode} mode)"
        badblocks ${opt} -o ${basename}.bb.${mode} ${disk}&
    done
    wait
}

zcavcheck() {
    for disk in $@; do
        local basename=$(basename ${disk})
        log "Running zcav on ${disk}"
        zcav -l ${basename}.zcav ${disk}
    done
}

draw_zcav() {
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
        local basename=$(basename ${disk})
        which gnuplot &> /dev/null && gnuplot -e "disk='${basename}'" gnuplot.gp
    done
}

checkusage "$@"
checkperms "$@"
checkdeps

BASEDIR="diskcheck-$(date +%FT%T)"; mkdir ${BASEDIR}
pushd ${BASEDIR}
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
