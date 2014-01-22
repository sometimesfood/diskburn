#!/bin/bash

CHECK_RETURN=96 #Bit 5,6
BAD_RETURN=158  #Bit 1,2,3,4,7

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
    ret=$?
    if [ $(($ret & $BAD_RETURN)) -ne 0 ]; then
        bad_drives="$bad_drives $disk"
    elif [ $(($ret & $CHECK_RETURN)) -ne 0 ]; then
        check_drives="$check_drives $disk"
    fi
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

uniq_values () {
    printf "%q\n" "$@" | sort -u
}

flatten () {
    echo "$@" | tr '\n' ' '
}

report_smart() {
    bad_drives="$(uniq_values $bad_drives)"
    check_drives="$(uniq_values $check_drives | grep -v -f <(echo "$bad_drives") )"
    log "CHECK: \E[33m$(flatten $check_drives)\E[0m"
    log "BAD: \E[31m$(flatten $bad_drives)\E[0m"
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
    report_smart
    popd
}

main "$@"
