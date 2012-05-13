#!/usr/bin/env bash
# runclipboard.sh by Scott Buchanan <buchanan.sc@gmail.com> http://wafflesnatcha.github.com
SCRIPT_NAME="runclipboard.sh"
SCRIPT_VERSION="1.0.3 2012-05-08"

usage() {
cat <<EOF
$SCRIPT_NAME $SCRIPT_VERSION
Run the contents of the clipboard as a script.
$([[ "$TERM" =~ xterm-(256)?color ]]&&echo -e '\033[1;31m\033[7m')
WARNING: This script will run ANYTHING on the clipboard!
$([[ "$TERM" =~ xterm-(256)?color ]]&&echo -e '\033[m')
Usage: ${0##*/} [OPTION]... [-- [ARGUMENT]...]

Options:
 -i, --interpreter UTILITY  Specify an interpreter (bash, ruby, /bin/sh, ...)
 -h, --help                 Show this help
EOF
}

ERROR() { [[ $1 ]] && echo "$SCRIPT_NAME: $1" >&2; [[ $2 > -1 ]] && exit $2; }

tempfile() {
	eval $1=$(mktemp -t "${0##*/}")
	tempfile_exit="$tempfile_exit rm -f '${!1}';"
	trap "{ $tempfile_exit }" EXIT
}

get_interpreter() { which "$1" 2>&1; }

while (($#)); do
	case $1 in
		-h|--help) usage; exit 0 ;;
		-i|--interpreter)
		opt_interpreter=$(get_interpreter "$2" 2>&1)
		[[ ! $? = 0 ]] && ERROR "bad interpreter" 1
		shift
		;;
		--) break ;;
		-*|--*) ERROR "unknown option ${1}" 1 ;;
		*) break ;;
	esac
	shift
done

tempfile tmpfile
pbpaste > "$tmpfile"

first_line="$(HEAD -n 1 "$tmpfile")"

if [[ $opt_interpreter ]]; then
	[[ "$first_line" =~ ^#\! ]] && tail -n +2 "$tmpfile" > "$tmpfile"
	prepend="#!${opt_interpreter}"
elif [[ ! "$first_line" =~ ^#\! ]]; then
	case "$first_line" in
		"<?php"*)
		prepend="#!$(get_interpreter "php")"
		[[ ! $? = 0 ]] && prepend=
		;;
		*)
		prepend="#!/usr/bin/env bash"
		;;
	esac
fi

if [[ $prepend ]]; then
	tempfile tmpfile2
	echo "${prepend}" > "$tmpfile2"
	cat "$tmpfile" >> "$tmpfile2"
	cp "$tmpfile2" "$tmpfile"
fi

chmod +x "$tmpfile"
"$tmpfile" "$@"
