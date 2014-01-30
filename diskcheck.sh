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
    badblocks -sw -o ${basename}.bb ${disk} 2> ${basename}.bb.progress &
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
    local plotfile="${basename}.gp"
    cat <<EOF > ${plotfile}
#!/usr/bin/env gnuplot
unset autoscale x
unset autoscale y
set autoscale xmin
set autoscale xmax
set autoscale ymin
set autoscale ymax
set xlabel "position (MB)"
set ylabel "transfer rate (MB/s)"
set terminal png size 2560,960
set output "${basename}.zcav.png"
set nokey
set multiplot layout 1,2 title "${basename}"
set title "reads"
plot "${basename}.read.zcav" pt 1 ps 1
set title "writes"
plot "${basename}.write.zcav" pt 1 ps 1
unset multiplot
EOF
    chmod +x "${plotfile}"
    hash gnuplot >/dev/null 2>&1 && gnuplot "${plotfile}"
}

report_bad_disks() {
    local bad_mask=158 # bits 1,2,3,4,7
    local fishy_mask=96 # bits 5,6
    local bad=''
    local fishy=''
    for disk in $@; do
        smartctl -d sat --all ${disk} > /dev/null
        ret=$?
        [[ $(($ret & ${bad_mask})) -ne 0 ]] && bad="${bad} ${disk}"
        [[ $(($ret & ${fishy_mask})) -ne 0 ]] && fishy="${fishy} ${disk}"
    done
    [[ "${bad}" ]] && log "Bad disks: ${bad}"
    [[ "${fishy}" ]] && log "Fishy disks: ${fishy}"
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
        smartctl -d sat --test=short "${disk}"
        bbcheck "${disk}"
    done
    wait

    for disk in $@; do
        smartcheck 2 "${disk}"
        zcavcheck 'read' "${disk}"
        smartcheck 3 "${disk}"
        zcavcheck 'write' "${disk}"
        smartcheck 4 "${disk}"
        draw_zcav "${disk}"
    done

    log "Finished diskcheck on $@"
    report_bad_disks "$@"
    popd
}

main "$@"
