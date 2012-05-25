# count_lines [PATH]
# Recursively count the total lines in all text files contained in `PATH`.
# 
# Skips files in .svn and .git directories, and skips non-text files (files
# whose mime-type doesn't start with "text/")
count_lines() { find "${1:-$PWD}" -not -path '*/.svn/*' -not -path '*/.git/*' -type f -exec bash -c '[[ `file -b --mime-type {}` =~ ^text/ ]]' \; -print | xargs wc -l; }