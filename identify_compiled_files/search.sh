#!/bin/bash


is_file_exits() {
	local file="$1"
	[[ -f "$file" ]] && return 0 || return 1
}

read_file() {
	local file="$1"
	local pattern="$2"
	echo -e "Searching: <$pattern>"
	if ( is_file_exits "$file" )
		then
		while read line
		do
			local op=$(grep -e $pattern $line 2>&1)
			if [[ $op != "" ]]; then
				echo -e "Searching: <$pattern> in $line\n$op\n"
			fi
		done < $file
	else
		echo "File $file does not exists"
	fi
}
if [[ $# -eq 2 ]]; then
	read_file $1 $2
else
	echo "Usage: $0 <compiled.files> <search pattern>"
fi


