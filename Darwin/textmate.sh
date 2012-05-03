# Escape a string for use in perl regex
# Usage: regex_escape STRING
regex_escape() { echo "$@" | perl -pe 's/(.*)/\Q\1\E/'; }

tempfile() {
	for var in "$@"; do
		eval $var="$(mktemp -t "${0##*/}")"
		tempfile_files="$tempfile_files '${!var}'"
	done
	trap "rm -f $tempfile_files" EXIT
}

# Output the path to COMMAND, if COMMAND is in the current $PATH and executable. Otherwise, shows and error message and returns 1.
# Usage: require COMMAND
require() { type -p "$@" || { tooltip_error "Required command not found: $@"; return 1; }; }

# Allows you to accept STDIN to a function call
function_input() { while read -r data; do echo -e "$data"; done; }

# Open a file in textmate at
# Usage: textmate_open FILE [LINE, [COLUMN]]
textmate_open() { open "txmt://open?url=file://$1${2:+&line=$2}${3:+&column=$3}"; }

# Shortcut to textmate_open "${TM_FILEPATH}"
# Usage: textmate_goto [LINE, [COLUMN]]
textmate_goto() { textmate_open "${TM_FILEPATH}" $1 $2; }


#
# HTML functions
#

html_encode() {
	{ [ -z "$1" ] && function_input || echo -e "${@}"; } |
		perl -pe '$| = 1; s/^[\s]*$//g; s/[ \t]*$//g; s/&/&amp;/g; s/</&lt;/g; s/>/&gt;/g;'
}

# same as html_encode, but also turns newlines into <br>
html_encode_pre() {
	{ [ -z "$1" ] && function_input || echo -e "${@}"; } |
		perl -pe '$| = 1; s/&/&amp;/g; s/</&lt;/g; s/>/&gt;/g; s/$\\n/<br>/g;'
}

html_redirect() {
	exit_show_html "<script type=\"text/javascript\">window.location='${1//\'/\'}';</script>"
}

# Switch to a nicely formatted HTML error message
# Usage: html_error "text"
# Usage: cat some/file.txt | html_error
html_error() {
	[[ $TM_FILEPATH ]] && url_param="url=file:\/\/${TM_FILEPATH//\//\\/}\&"
	. "$TM_SUPPORT_PATH/lib/webpreview.sh"
	html_header "${2:-ERROR}"
	echo "<pre>"
	html_encode "$@" |
		perl -pe 's/(^.*?)((?:line )?(\d+)(?: column |\:)?(\d+))(.*$)/$1<a href=\"txmt:\/\/open\/\?'${url_param}'line=$3\&column=$4\">$2<\/a>$5/mi'
	echo "</pre>"
	html_footer
	exit_show_html
}

#
# Tool Tip functions
#

# Standard tooltip
tooltip() {
	tooltip_html default $(html_encode_pre "$@")
}

# Red tooltip with an X on it
# nice to display when a command has failed
tooltip_error() {
	local input=$(html_encode_pre "$@")
	tooltip_html $([[ $input ]] && echo "styled" || echo "styled_empty") \
		--color 170,14,14 \
		--glyph "&#x2718;" \
		"$input"	
}

# Green tooltip with a checkmark
# nice to display when a command has successfully completed
tooltip_success() {
	local input=$(html_encode_pre "$@")
	tooltip_html $([[ $input ]] && echo "styled" || echo "styled_empty") \
		--color 57,154,21 \
		--glyph "&#x2714;" \
		"$input"
}

# Orange tooltip with an ! on it
tooltip_warning() {
	local input=$(html_encode_pre "$@")
	tooltip_html $([[ $input ]] && echo "styled" || echo "styled_empty") \
		--color 175,82,0 \
		--glyph '<span style="color:yellow">&#x26A0;</span>' \
		"$input"
}

# Shows a custom tooltip using $tooltip_template
# Usage:
#   tooltip_html default --color "12,139,245" --someothervar "this is the value"
# If your custom template has any %words% in it, simply pass them to this
# function as long arguments (i.e. tooltip_html --color 12,139,245)
tooltip_html() {
	local template="tooltip_template_$1"
	local replacement=
	local lookup=
	local html="$(echo "${!template}")"
	shift

	while (($#)); do
		[[ ! "$1" =~ ^-- ]] && break
		lookup="${1:2}"
		replacement=$(regex_escape "$2")
		html=$(echo "$html" | perl -pe "s/%${lookup}%/${replacement}/g")
		shift 2
	done
	
	replacement=$(regex_escape "${@:-$(function_input)}")
	html=$(echo "$html" | perl -pe "s/%text%/$replacement/g")
	"${DIALOG}" tooltip --transparent --html "$html" &>/dev/null &
}

#
# Extra exit functions
#

exit_tooltip() { tooltip "$@" && exit_discard; }
exit_tooltip_error() { tooltip_error "$@" && exit_discard; }
exit_tooltip_success() { tooltip_success "$@" && exit_discard; }
exit_tooltip_warning() { tooltip_warning "$@" && exit_discard; }

#
# Tooltip Templates
#

tooltip_template_default=$(cat <<'EOF'
<style>
html, body {
	background: none;
	border: 0;
	margin: 0;
	padding: 0;
}
body {
	padding: 1px 10px 14px;
}
pre, code, tt {
	font-family: Menlo, monaco, monospace;
	font-size: inherit;
	margin: 0;
}
.tooltip {
	-webkit-animation: fadeIn .2s ease 0s;
	-webkit-animation-fill-mode: forwards;
	-webkit-box-shadow: 0 0 0 1px rgba(0,0,0,.1), 0 5px 9px 0 rgba(0,0,0,.4);
	background: rgba(255,255,185,.95);
	color: #000;
	font: small-caption;
	opacity: 0;
	padding: 2px 3px 3px;
	position: relative;
}
@-webkit-keyframes fadeIn {	0% { opacity: 0 } 100% { opacity: .9999 } }
</style>
<div class="tooltip">%text%</div>
EOF)

tooltip_template_styled=$(cat <<'EOF'
<style>
html, body {
	background: none;
	border: 0;
	margin: 0;
	padding: 0;
}
body {
	padding: 1px 10px 14px;
}
pre, code, tt {
	font-family: Menlo, monaco, monospace;
	font-size: inherit;
	margin: 0;
}
.tooltip {
	-webkit-animation: fadeIn .2s ease 0s;
	-webkit-animation-fill-mode: forwards;
	-webkit-border-radius: 2px 0 0 2px;
	-webkit-box-shadow: 0 0 0 1px rgba(0,0,0,.1), 0 5px 9px 0 rgba(0,0,0,.4);
	background: rgba(%color%,.95);
	color: #fff;
	font: small-caption;
	opacity: 0;
	position: relative;
	text-shadow: 0 1px 0 rgba(0,0,0,.2);
}
@-webkit-keyframes fadeIn {	0% { opacity: 0 } 100% { opacity: .9999 } }
.glyph {
	-webkit-border-radius: 2px 0 0 2px;
	-webkit-box-shadow: -8px 0 8px -8px rgba(0,0,0,.3) inset;
	-webkit-box-sizing: border-box;
	-webkit-mask-image: -webkit-linear-gradient(top,rgba(0,0,0,1) 75%,rgba(0,0,0,.5));
	background-image: -webkit-linear-gradient(top,rgba(0,0,0,.2),rgba(0,0,0,.1));
	box-sizing: border-box;
	font-family: monospace, webdings;
	height: 100%;
	padding: 2px 0 0;
	position: absolute;
	text-align: center;
	text-shadow: 0 -1px 0 rgba(0,0,0,.2);
	width: 18px
}
.content {
	padding: 2px 3px 3px 4px;
	margin-left: 18px
}
</style>
<div class="tooltip">
	<div class="glyph">%glyph%</div>
	<div class="content">%text%</div>
</div>
EOF)

tooltip_template_styled_empty=$(cat <<'EOF'
<style>
html, body {
	background: none;
	border: 0;
	margin: 0;
	padding: 0;
}
body {
	padding: 1px 10px 14px;
}
.tooltip {
	-webkit-animation: fadeIn .2s ease 0s;
	-webkit-animation-fill-mode: forwards;
	-webkit-border-radius: 5px;
	-webkit-box-shadow: 0 0 0 1px rgba(0,0,0,.1), 0 5px 9px 0 rgba(0,0,0,.4);
	background: rgba(%color%,.95);
	color: #fff;
	font: 16px/25px monospace, webdings;
	height: 25px;
	opacity: 0;
	padding: 3px;
	position: relative;
	text-align: center;
	text-shadow: 0 1px 0 rgba(0,0,0,.2);
	width: 25px;
}
@-webkit-keyframes fadeIn {	0% { opacity: 0 } 100% { opacity: .9999 } }

</style>
<div class="tooltip">%glyph%</div>
EOF)



#
# Tests
#

# tooltip "cache.manifest"
# tooltip_error "Oh no an error!"
# tooltip_warning
# /usr/bin/php -v | tooltip_warning
# tooltip_success "This is a successful tooltip! :D ┌( ◔‿◔)┘ ʘ‿ʘ\nWow! Amazing! Zing!" && exit_discard
# tooltip_success
# tooltip "This is a successful tooltip! :D ┌( ◔‿◔)┘ ʘ‿ʘ\nWow! Amazing! Zing!"
