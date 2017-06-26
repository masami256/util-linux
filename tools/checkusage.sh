#!/bin/bash

## This script is potentially dangerous! Don't run it on
## arbitrary commands.

export LC_ALL=C

if [ "$#" -lt 1 ]; then
	echo "usage: $0 program..." >&2
	echo "       or try 'make checkusage' to check all built programs" >&2
	exit 1
fi

builddir="."
cmds=$(echo $@ | tr ' ' '\n' | sort)

## Set alternative options for --help, --version
## or --unknownopt. "x" means "not implemented".
##
## Examples:
##   alt_whereis__help="-h"  # in past whereis(1) had no longopt for --help
##   alt_more__help="x"      # more(1) had neither --help nor -h

alt_fsck__unknownopt="-Tunknown"  # no title (-T) and pass -unknown to fsck.foo

function exec_option {
	local cmdb=$1
	local cmd=$2
	opt=$3

	local alt="alt_${cmdb}${opt}"
	alt=${alt//-/_}
	alt=${alt//./_}
	alt=$(eval printf -- \"\$${alt}\")
	if test -n "$alt"; then
		if test "$alt" = "x"; then
			return 1
		fi
		opt=$alt
	fi

	out=$("$cmd" "$opt" 2>/dev/null)
	err=$("$cmd" "$opt" 2>&1 >/dev/null)
	ret=$?

	# hardcoded ... nologin should always return false
	if test "$cmdb" = "nologin" &&
			test "$opt" = "--help" -o "$opt" = "--version"; then
		if test "$ret" = "0"; then
			echo "$cmdb, $opt, should return false"
		fi
		ret=0
	fi

	return 0
}


function check_help {
	local cb=$1
	local c=$2

	if ! exec_option "$cb" "$c" --help; then
		return 1
	fi

	if test $ret != 0; then
		echo "$cb: $opt, returns error"
	else
		if test -z "$out"; then
			echo "$cb: $opt, no stdout"
		fi
		if test -n "$err"; then
			echo "$cb: $opt, non-empty stderr"
		fi
	fi
	return 0
}

function check_version {
	local cb=$1
	local c=$2

	if ! exec_option "$cb" "$c" --version; then
		return 1
	fi

	if test $ret != 0; then
		echo "$cb: $opt, returns error"
	else
		if test -z "$out"; then
			echo "$cb: $opt, no stdout"
		fi
		if test -n "$err"; then
			echo "$cb: $opt, non-empty stderr"
		fi
	fi
}

function check_unknownopt {
	local cb=$1
	local c=$2
	local nohelp=$3

	if ! exec_option "$cb" "$c" --unknownopt; then
		return 1
	fi

	if test $ret = 0; then
		echo "$cb: $opt, returns no error"
	fi
	if test -n "$out"; then
		echo "$cb: $opt, non-empty stdout"
	fi
	if test -z "$err"; then
		echo "$cb: $opt, no stderr"
	elif test -z "$nohelp" -o "$nohelp" != "yes"; then
		out_len=$(echo "$out" | wc -l)
		err_len=$(echo "$err" | wc -l)
		if test "$err_len" -gt 2; then
			# hardcoded ignore ... mkfs sends options to mkfs.ext2
			if test "$cb" != "mkfs" -a "$cb" != "fsck"; then
				echo "$cb: $opt, stderr too long: $err_len"
			fi
		elif test "$err_len" -lt 2; then
			echo "$cb: $opt, stderr too short: $err_len"
		fi
	fi
}

for cb in $cmds; do
	c="$builddir/$cb"
	if ! type "$c" &>/dev/null; then
		echo "$cb: does not exist"
		continue
	fi

	nohelp="no"
	if ! check_help "$cb" "$c"; then
		nohelp="yes"
	fi
	check_version "$cb" "$c"
	check_unknownopt "$cb" "$c" "$nohelp"
done

