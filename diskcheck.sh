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
    local check_no="$1"
    local disk="$2"
    local basename="$(basename ${disk})"
    log "Running SMART check #${check_no} on ${disk}"
    smartctl -d sat --all ${disk} > ${basename}.smart.${check_no}
}

bbcheck() {
    local disk="$1"
    local basename="$(basename ${disk})"
    log "Checking ${disk} for bad blocks..."
    badblocks -w -o ${basename}.bb ${disk} &
}

zcavcheck() {
    local mode="$1"
    local disk="$2"
    local basename="$(basename ${disk})"
    [[ ${mode} = "write" ]] && local opt="-w" || local opt=""
    log "Running zcav on ${disk} (${mode} mode)"
    zcav ${opt} -l ${basename}.${mode}.zcav ${disk}
}

draw_zcav() {
    local disk="$1"
    local basename="$(basename ${disk})"
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
set title "reads"
plot disk.".read.zcav" pt 1 ps 1
set title "writes"
plot disk.".write.zcav" pt 1 ps 1
unset multiplot
EOF
    which gnuplot &> /dev/null && gnuplot -e "disk='${basename}'" gnuplot.gp
}

main() {
    checkusage "$@"
    checkperms "$@"
    checkdeps

    local basedir="diskcheck-$(date +%FT%T)"
    mkdir ${basedir}
    pushd ${basedir}
    log "Starting diskcheck on $@"

    for disk in $@; do
        smartcheck 1 "${disk}"
        bbcheck "${disk}"
    done
    wait

    for disk in $@; do
        smartcheck 2 "${disk}"
        zcavcheck read "${disk}"
        smartcheck 3 "${disk}"
        zcavcheck write "${disk}"
        smartcheck 4 "${disk}"
        draw_zcav "${disk}"
    done

    log "Finished diskcheck on $@"
    popd
}

main "$@"
