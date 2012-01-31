#!/usr/bin/env bash
SCRIPT_NAME="benchmark"
SCRIPT_VERSION="0.3.6 (2012-01-30)"
SCRIPT_GETOPT_SHORT="c:i:d:o:h"
SCRIPT_GETOPT_LONG="command:,iterations:,delay:,output:,help"

opt_command=
opt_delay=2
opt_iterations=10
opt_output=

usage() {
cat <<EOF
$SCRIPT_NAME $SCRIPT_VERSION
Benchmark a shell script.

Usage: ${0##*/} [options]

Options:
 -c, --command=COMMAND  Specify the command to benchmark
 -d, --delay=SECONDS    Seconds to wait in between executions (${opt_delay})
 -i, --iterations=NUM   Number of iterations to run (${opt_iterations})
 -o, --output=PATH      Write results to a file
 -h, --help             Show this help
EOF
}
FAIL() { [[ $1 ]] && echo "$SCRIPT_NAME: $1" >&2; exit ${2:-1}; }

ARGS=$(getopt -s bash -o "$SCRIPT_GETOPT_SHORT" -l "$SCRIPT_GETOPT_LONG" -n "$SCRIPT_NAME" -- "$@") || exit
eval set -- "$ARGS"

tempfile() {
	eval $1=$(mktemp -t "${0##*/}")
	tempfile_exit="$tempfile_exit rm -f '${!1}';"
	trap "{ $tempfile_exit }" EXIT
}

getStdIn() {
    tempfile TMPCMD
    cat - > "$TMPCMD"
    chmod +x "$TMPCMD"
    opt_command="$TMPCMD"
}

TIME_BIN=`which time | sed 1q`
[[ ! $TIME_BIN ]] && FAIL "can't locate time program"

while true; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        -c|--command) opt_command="$2"; shift ;;
        -d|--delay) opt_delay=$2; shift ;;
        -i|--iterations) opt_iterations=$2; shift ;;
        -o|--output) opt_output=$2; shift ;;
        *) shift; break ;;
    esac
    shift
done

[[ -z "$opt_command" ]] && getStdIn

tempfile TMPFILE

echo -n "benchmarking... "
tput sc
for (( i = 1; i <= $opt_iterations; i++ )); do
    tput rc
    echo -n "$i/$opt_iterations"
    sleep $opt_delay
    { $TIME_BIN $opt_command
} 2>> $TMPFILE
done
tput rc
echo

[[ "${opt_output}" ]] && mv "${TMPFILE}" "${opt_output}" || cat "${TMPFILE}"
