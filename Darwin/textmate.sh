#!/usr/bin/env bash
# textmate.sh by Scott Buchanan <buchanan.sc@gmail.com> http://wafflesnatcha.github.com
# Handy functions to include in your TextMate commands

# regex_escape STRING
# Escape a string for use in perl regex
regex_escape() {
	echo "$@" | perl -pe 's/(.*)/\Q\1\E/'
}
export -f regex_escape

# temp_file VARIABLE_NAME...
# Generate a temporary file, saving its path in a variable named `VARIABLE_NAME`.
#
# Automatically deletes the file when the current script/program ends.
#
# Example:
# $ temp_file temp1 temp2 temp3
# $ echo "temp1=$temp1"
# $ echo "temp2=$temp2"
# $ echo "temp3=$temp3"
# $ echo "but these files will be deleted as soon as this script ends..."
temp_file() {
	local _temp_file__var
	for _temp_file__var in "$@"; do
		eval $_temp_file__var=\"$(mktemp -t "${0##*/}")\"
		_temp_file__files="$_temp_file__files '${!_temp_file__var}'"
	done
	trap "rm -f $_temp_file__files" EXIT
}
export -f temp_file

# require COMMAND
#
# Returns the path to COMMAND, if COMMAND is in the current $PATH and executable.
# Otherwise, shows an error tooltip and returns 1.
#
# Example:
# $ bin=$(require uglifyjs) || exit_discard
require() {
	type -p "$@" && return
	tooltip_error "Required command not found: $@"
	return 1
}
export -f require

# function_stdin
# Allows you to accept STDIN to a function call
#
# Example:
# $ fn() { echo "${@:-$(function_stdin)}"; }; fn "testing"; echo "testing" | fn
function_stdin() {
	local oldIFS=$IFS
	IFS="$(printf "\n")"
	local line
	while read -r line; do
		echo -e "$line"
	done
	IFS=$oldIFS
}
export -f function_stdin

# textmate_goto [FILE]
# textmate_goto [FILE] [LINE]
# textmate_goto [FILE] [LINE] [COLUMN]
# textmate_goto [LINE] [COLUMN]
#
# Open a file (or the current file) in textmate at a given LINE and COLUMN.
textmate_goto() {
	if [[ ! -f "$1" ]]; then
		open "txmt://open?url=file://${TM_FILEPATH}${1:+&line=$1}${2:+&column=$2}"
		return
	fi
	local f="$1"
	[[ ! "${1:0:1}" = "/" && -f "$PWD/$1" ]] && f="$PWD/$1"
	open "txmt://open?url=file://${f}${2:+&line=$2}${3:+&column=$3}"
}
export -f textmate_goto

#
# HTML functions
#

# html_encode [TEXT]
#
# HTML encode text <, >, &
#
# Examples:
# $ html_encode "<some text> you want to encode & stuff"
# $ cat "/some/file.html" | html_encode
html_encode() {
	echo -en "${@:-$(function_stdin)}" | perl -pe '$|=1; s/&/&amp;/g; s/</&lt;/g; s/>/&gt;/g;'
}
export -f html_encode

# html_encode_br [TEXT]
#
# Same as `html_encode`, but also changes `\n` to `<br>`
html_encode_br() {
	html_encode "${@:-$(function_stdin)}" | perl -pe 's/\n/<br>/g;'
}
export -f html_encode_br

# html_redirect URL
#
# Show the HTML window, and redirect to a URL.
html_redirect() {
	. "$TM_SUPPORT_PATH/lib/html.sh" && redirect "$@" && exit_show_html
}
export -f html_redirect

# html_header [TITLE]
# html_header TITLE [SUBTITLE]
# html_header WINDOW_TITLE TITLE [SUBTITLE]
#
# Replacement for `html_header` of `$TM_SUPPORT_PATH/lib/webpreview.sh`.
html_header() {
	# Stop if html_header has already been called
	[[ $_html_head ]] && return 1

	case ${#@} in
		1) export WINDOW_TITLE="$1" PAGE_TITLE="$1" ;;
		2) export WINDOW_TITLE="$1" PAGE_TITLE="$1" SUB_TITLE="$2" ;;
		3) export WINDOW_TITLE="$1" PAGE_TITLE="$2" SUB_TITLE="$3" ;;
	esac
	export _html_head="$( [[ -f "$TM_FILEPATH" ]] && echo "<base href=\"file://${TM_FILEPATH// /%20}\">" )"
	"${TM_RUBY:-ruby}" -r "$TM_SUPPORT_PATH/lib/web_preview.rb" <<-'RUBY'
		puts html_head(
			:window_title => ENV['WINDOW_TITLE'],
			:page_title => ENV['PAGE_TITLE'],
			:sub_title => ENV['SUB_TITLE'],
			:html_head => ENV['TM_html_header']
		)
	RUBY
}
export -f html_header

# html_footer
#
# Replacement for `html_footer` of `$TM_SUPPORT_PATH/lib/webpreview.sh`.
html_footer() {
	echo -e '\n  </div>\n</body>\n</html>'
}
export -f html_footer

# Additional HTML for the web preview <head>
export TM_html_header=$(cat <<'HTML'
<script type="text/javascript">
var TM = (function () {
	function init() {
		var t, i, node, links = document.links,
			ll = links.length,
			h = function (e) {
				e.preventDefault();
				open(this.href || e.srcElement.href);
			};
		for (i = 0; i < ll; i++) {
			node = links[i];
			if (node.href.match(/^https?:/)) {
				node.setAttribute('rel', 'external');
				t = node.getAttribute('title');
				if (!t || t === "") {
					node.setAttribute('title', node.href);
				}
				node.addEventListener('click', h, false);
			}
		}
	}
	function open(url) {
		TextMate.system("open '" + String(url).replace("'", "\'") + "'", null);
	}
	window.addEventListener("load", init, false);
	return {
		open: open
	};
}());
</script>
HTML)

# html_error [TEXT]
# Open a nicely formatted HTML error message
#
# Examples:
# $ html_error "text"
# $ cat some/file.txt | html_error
html_error() {
	# [[ $TM_FILEPATH ]] && url_param="url=file:\/\/${TM_FILEPATH//\//\\/}\&"
	[[ $TM_FILEPATH ]] && url_param="$(regex_escape "url=file://${TM_FILEPATH}&")"
	# . "$TM_SUPPORT_PATH/lib/webpreview.sh"
	html_header "${2:-Error}"
	echo -n '<pre><code>'
	# echo "$(html_encode "$@" | perl -pe 's/(^.*?)((?:line )?(\d+)(?: column |\:)?(\d+))(.*$)/$1<a href=\"txmt:\/\/open\/\?'"${url_param}"'line=$3\&column=$4\">$2<\/a>$5/mi')"
	echo "$(html_encode "$@")"
	echo '</code></pre>'
	html_footer
	exit_show_html
}
export -f html_error

#
# Tooltip functions
#

# tooltip [TEXT]
#
# Show a standard tooltip.
tooltip() {
	tooltip_template default --text "$(html_encode_br "$@")"
}
export -f tooltip

# tooltip_html [HTML]
#
# Show a standard tooltip with HTML content.
tooltip_html() {
	tooltip_template default --text "${@:-$(function_stdin)}"
}
export -f tooltip_html

# tooltip_error [TEXT]
#
# Red tooltip with a ✘, used for a command has failed.
tooltip_error() {
	local input="$(html_encode_br "$@")"
	tooltip_template $([[ $input ]] && echo "styled" || echo "styled_notext") --text "$input" --color 170,14,14 --glyph '&#x2718;'
}
export -f tooltip_error

# tooltip_success [TEXT]
#
# Green tooltip with a ✔, used for a command has successfully completed.
tooltip_success() {
	local input="$(html_encode_br "$@")"
	tooltip_template $([[ $input ]] && echo "styled" || echo "styled_notext") --text "$input" --color 57,154,21 --glyph '&#x2714;'
}
export -f tooltip_success

# tooltip_warning [TEXT]
#
# Orange tooltip with a ⚠, used for warnings and such.
tooltip_warning() {
	local input="$(html_encode_br "$@")"
	tooltip_template $([[ $input ]] && echo "styled" || echo "styled_notext") --text "$input" --color 175,82,0 --glyph '<b class="bigger" style="color:yellow">&#x26A0;</b>'
}
export -f tooltip_warning

# tooltip_template TEMPLATE [--VAR REPLACEMENT]...
#
# Show a custom tooltip using $TM_tooltip_template
#
# If your custom template has any <%words%> in it, simply pass them to this
# function as long arguments (i.e. tooltip_template --color 12,139,245).
# See the included templates for more information.
#
# Example:
# $ tooltip_template default --text "This is the tooltip text."
# $ tooltip_template default --color "12,139,245" --text "This is the tooltip text."
# $ tooltip_template default --color "12,139,245" --text "This is the tooltip text."
tooltip_template() {
	local template="TM_tooltip_template_$1"
	local replacement=
	local lookup=
	local html="$(echo "${!template}")"
	shift

	# Replace <%words%>
	while (($#)); do
		[[ ! "$1" =~ ^-- ]] && break
		lookup="${1:2}"
		# replacement=$(regex_escape "$2")
		html=$(echo "$html" | perl -pe "s/<%${lookup}%([^>]*)>/$(regex_escape "$2")/g")
		shift 2
	done

	# Replace <%words%> that weren't specified (with their default values if possible)
	html=$(echo "$html" | perl -pe "s/<%([a-z0-9\-\_]+)%([^>]*)>/\$2/gi")

	"${DIALOG}" tooltip --transparent --html "$html" &>/dev/null &
}
export -f tooltip_template

#
# Extra exit functions
#

exit_tooltip() { tooltip "$@" && exit_discard; }
export -f exit_tooltip
exit_tooltip_error() { tooltip_error "$@" && exit_discard; }
export -f exit_tooltip_error
exit_tooltip_success() { tooltip_success "$@" && exit_discard; }
export -f exit_tooltip_success
exit_tooltip_warning() { tooltip_warning "$@" && exit_discard; }
export -f exit_tooltip_warning

#
# Tooltip Templates
#

# Variables: text, [color]
export TM_tooltip_template_default=$(cat <<'HTML'
<style>html,body{background:0;border:0;margin:0;padding:0}body{font:small-caption;padding:1px 10px 14px}h1,h2,h3,h4,h5,h6{display:inline;margin:0;padding:0;}pre,code,tt{font-family:Menlo,Monaco,monospace;font-size:inherit;margin:0}
.tooltip{-webkit-animation:fadeIn .2s ease 0s;-webkit-animation-fill-mode:forwards;-webkit-box-shadow:0 0 0 1px rgba(0,0,0,.1),0 5px 9px 0 rgba(0,0,0,.4);background:rgba(<%color%255,255,185>,.95);color:#000;font:small-caption;opacity:0;padding:2px 3px 3px;position:relative}
@-webkit-keyframes fadeIn{0%{opacity:0}100%{opacity:.9999}}
</style><div class="tooltip"><%text%></div>
HTML)

# Variables: glyph, text, [color]
export TM_tooltip_template_styled=$(cat <<'HTML'
<style>html,body{background:0;border:0;margin:0;padding:0}body{font:small-caption;font-size:11px;line-height:13px;padding:1px 10px 14px}pre,code,tt{font-family:Menlo,Monaco,monospace;font-size:inherit;margin:0}
.tooltip{-webkit-animation:fadeIn .2s ease 0s;-webkit-animation-fill-mode:forwards;-webkit-border-radius:2px;-webkit-box-shadow:0 0 0 1px rgba(0,0,0,.1),0 5px 9px rgba(0,0,0,.4);background:rgba(<%color%255,255,185>,.95);color:#fff;opacity:0;overflow:hidden;position:relative;text-shadow:0 1px 0 rgba(0,0,0,.2)}
.glyph{-webkit-border-radius:2px 0 0 2px;-webkit-box-shadow:-8px 0 8px -8px rgba(0,0,0,.3) inset;-webkit-box-sizing:border-box;-webkit-mask-image:-webkit-linear-gradient(top,rgba(0,0,0,1)75%,rgba(0,0,0,.5));background-image:-webkit-linear-gradient(top,rgba(0,0,0,.2),rgba(0,0,0,.1));box-sizing:border-box;font-family:webdings,freesans,freeserif,monospace,sans-serif,serif;height:100%;padding:2px 0 0;position:absolute;text-align:center;text-shadow:0 -1px 0 rgba(0,0,0,.2);width:19px}
.glyph .bigger{font-size:13px;line-height:17px}
.text{margin-left:19px;padding:2px 3px 3px 4px}
@-webkit-keyframes fadeIn{0%{opacity:0}100%{opacity:.9999}}
</style><div class="tooltip"><div class="glyph"><%glyph%></div><div class="text"><%text%></div></div>
HTML)

# Variables: glyph, [color]
export TM_tooltip_template_styled_notext=$(cat <<'HTML'
<style>html,body{background:0;border:0;margin:0;padding:0}body{padding:1px 10px 14px}
.tooltip{-webkit-animation:fadeIn .2s ease 0s;-webkit-animation-fill-mode:forwards;-webkit-border-radius:5px;-webkit-box-shadow:0 0 0 1px rgba(0,0,0,.1),0 5px 9px 0 rgba(0,0,0,.4);background:rgba(<%color%255,255,185>,.95);color:#fff;font:16px/25px webdings,monospace,sans-serif,serif;height:25px;opacity:0;padding:3px;position:relative;text-align:center;text-shadow:0 1px 0 rgba(0,0,0,.2);width:25px}
@-webkit-keyframes fadeIn{0%{opacity:0}100%{opacity:.9999}}
</style><div class="tooltip"><%glyph%></div>
HTML)


#
# Tests
#

# tooltip_error "Oh no an error!"
# tooltip_warning
# /usr/bin/php -v | tooltip_warning
# tooltip_success "This is a successful tooltip! :D ┌( ◔‿◔)┘ ʘ‿ʘ\nWow! Amazing! Zing!" && exit_discard
# tooltip_success
# tooltip "This is a successful tooltip! :D ┌( ◔‿◔)┘ ʘ‿ʘ\nWow! Amazing! Zing!"
