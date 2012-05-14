#!/bin/sh

SHORTOPTS="LMUc:w:nqvho:O:"
DEPS="cryptsetup blkid findmnt mkswap mktemp"

LOGLEVEL=1
DRYRUN=0
WAITTIME=10
CRYPTTAB=/etc/crypttab
OPTIONS=
FILTER="!noauto"

ct_print_usage() {
	cat <<__EOF__
usage: $0 [OPTIONS] [-L]
       $0 [OPTIONS] -M [NAME|DEVICE]
       $0 [OPTIONS] -M NAME DEVICE [KEY]
       $0 [OPTIONS] -U [NAME[,...]]

  List, map, and unmap encrypted volumes. The utility is a wrapper for
  cryptsetup which makes use of a crypttab file.

  actions:
    -L       list the names of volumes defined in crypttab, this is
             the default
    -M       map a volume defined in crypttab or defined on the command
             line. with no arguments, map all volumes without the noauto
             option
    -U       unmap volumes defined in crypttab. with no arguments, unmap
             all volumes without the noauto option

  options:
    -c FILE  set the crypttab location (default: /etc/crypttab)
    -w NUM   wait time (seconds) for a device if it is not already available
    -n       dry run
    -q       decrease verbosity
    -v       increase verbosity
    -h       print this message
    -o OPT[,...]
             options which are appened to the options defined in crypttab
             (they take precedence). specifying this multiple times is
             cumulative
    -O OPT[,...]
             filter used *only* when no volumes are given on the command
             line. an option may start with a ! to require that it must not
             be present. specifying this multiple times is cumulative

__EOF__
	exit $1
}

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
#                                                                              #
# Utilities                                                                    #
#                                                                              #

error() {
	[ $LOGLEVEL -ge 0 ] && printf "E: %s\n" "$*" >&2 || true
}

die() {
	printf "E: %s\n" "$*" >&2
	exit ${1:-1}
}

warn() {
	[ $LOGLEVEL -ge 1 ] && printf "W: %s\n" "$*" >&2 || true
}

msg() {
	[ $LOGLEVEL -ge 1 ] && printf "M: %s\n" "$*" >&2 || true
}

info() {
	[ $LOGLEVEL -ge 2 ] && printf "I: %s\n" "$*" >&2 || true
}

run() {
	[ $LOGLEVEL -ge 2 ] && printf "R: %s\n" "$*" >&2
	if [ $DRYRUN -eq 1 ]; then
		true
	else
		"$@"
	fi
}

trim() {
	local IFS=$' \t\n'
	echo -n $*
}

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
#                                                                              #
# Main functions                                                               #
#                                                                              #

ct_main() {

	local action

	set_action() {
		if [ -z $action ]; then
			action="$@"
		else
			error "only one of -L, -M, or -U may be given"
			ct_print_usage 1
		fi
	}

	while getopts ":$SHORTOPTS" opt ; do

		case $opt in
			L) set_action list;;
			M) set_action map;;
			U) set_action unmap;;
			c) CRYPTTAB="$OPTARG";;
			w) WAITTIME=${OPTARG//[!0-9]};;
			n) DRYRUN=1;;
			q) LOGLEVEL=$(( LOGLEVEL - 1 ));;
			v) LOGLEVEL=$(( LOGLEVEL + 1 ));;
			h) ct_print_usage 0;;
			o) OPTIONS="$OPTIONS,$OPTARG";;
			O) FILTER="$FILTER,$OPTARG";;
			:)
				error "option requires an argument -- '$OPTARG'"
				ct_print_usage 1
				;;
			?)
				error "invalid option -- '$OPTARG'"
				ct_print_usage 1
				;;
		esac

	done

	shift $(( OPTIND - 1 ))

	# Warn if any of the dependencies are missing
	for dep in $DEPS; do
		type $dep &> /dev/null || info "$dep not found, some functionality may fail"
	done

	if [ -z "$action" -o "$action" = "list" ]; then

		:

	elif [ "$action" = "unmap" ]; then

		:

	elif [ "$action" = "map" ]; then

		:

	else

		error "Internal error: no action"
		false

	fi
}


# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
#                                                                              #
# Functions for iterating over crypttab                                        #
#                                                                              #

ct_read_crypttab() {

	if [ ! -f "$CRYPTTAB" -o ! -r "$CRYPTTAB" ]; then
		error "cannot read $CRYPTTAB"
		return 1
	fi

	local func="$@" line lineno=0 name dev key options ret=0 adhoc=0

	if [ "$1" = "-1" ]; then
		adhoc=1
		shift
		func="$@"
	fi

	while read -r name dev key options <&3; do

		lineno=$(( lineno + 1 ))
		[ -z "$name" ] || [ ${name:0:1} = "#" ] && continue

		# unescape devname and keyname
		name=$(printf '%b' "$name")
		dev=$(printf '%b' "$dev")
		key=$(printf '%b' "$key")

		if [ -z "$name" ]; then
			warn "$CRYPTTAB:$lineno: the name (first column) cannot be blank"
			continue
		elif [ -z "$dev" ]; then
			warn "$CRYPTTAB:$lineno: the device (second column) cannot be blank"
			continue
		fi

		case $key in
			-|none|"")
				key=-
				;;
			/dev/random|/dev/urandom)
				options="$options,%random"
				;;
			/*|UUID=*|PARTUUID=*|LABEL=*)
				:
				;;
			*)
				warn "$CRYPTTAB:$lineno: plain text keys are not supported"
				key=-
				;;
		esac

		if ct_check_filter $options; then
			if ! $func "$name" "$dev" "$key" $options; then
				ret=$(( ret + 1 ))
			elif [ $adhoc -eq 1 ]; then
				ret=0
				break
			fi
		fi

	done 3< "$CRYPTTAB"

	return $ret
}

ct_check_filter() {

	local IFS=$',' fltr opt

	for fltr in $FILTER; do
		fltr="$(trim $fltr)"
		[ -z "$fltr" ] && continue

		if [ "x${fltr:0:1}" != "x!" ]; then

			for opt in $*; do
				opt="$(trim $opt)"
				[ -z "$opt" ] && continue

				if [ "$fltr" = "$opt" -o "$fltr" = "${opt%%=*}" ]; then
					continue 2
				fi
			done

			return 1

		else

			for opt in $*; do
				opt="$(trim $opt)"
				[ -z "$opt" ] && continue

				if [ "$fltr" = "!$opt" -o "$fltr" = "!${opt%%=*}" ]; then
					return 1
				fi
			done

		fi

	done

	return 0
}

#                                                                              #
# ---------------------------------------------------------------------------- #

ct_main "$@"

# vim: set ft=sh noet ts=2 sw=2 :
