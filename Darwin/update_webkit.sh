#!/usr/bin/env bash

snapshots_url="http://nightly.webkit.org"
download_dir="$TMPDIR/webkit-nightly"
install_dir="/Applications"
bundle_identifier="org.webkit.nightly.WebKit"

echo -n "checking for existing installation... "
if [[ $(type -p find_app) ]]; then
	app_path=$(find_app "${bundle_identifier}")
else
	app_path=$(osascript -e 'tell application "Finder" to return POSIX path of (path to application id "'${bundle_identifier}'")')
	osascript -e 'if application id "'${bundle_identifier}'" is running then tell application id "'${bundle_identifier}'" to quit'
fi

if [[ $? = 0 && -e "$app_path" ]]; then 
	echo "$app_path"
	install_dir="$(dirname "$app_path")"
else
	echo "not found"
fi

echo -n "finding latest build... "
URL="$(curl -qsSL --max-time 10 --connect-timeout 15 ${snapshots_url} | grep dmg | head -1 | perl -pe 's/.*(http.*dmg).*/$1/')"
FILE="$(basename "$URL")"
echo $FILE

echo "downloading... "
mkdir -p "$download_dir" && cd "$download_dir"
curl -qSL# --connect-timeout 15 "$URL" -o "$FILE"

echo "mounting... "
hdiutil attach -quiet "$download_dir/$FILE"

echo "installing into [${install_dir}]... "
[[ -e "$install_dir/WebKit.app" ]] && mv "$install_dir/WebKit.app" ~/.Trash/WebKit-$(date +%Y-%m-%d_%H-%M-%s).app/
cp -R "/Volumes/WebKit/WebKit.app" "$install_dir/"

echo "cleaning up... "
hdiutil detach -quiet /Volumes/WebKit
[[ -e "$download_dir" ]] && rm -rf $download_dir
