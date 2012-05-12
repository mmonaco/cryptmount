#!/bin/sh

SHORTOPTS="LMUc:w:nqvho:O:"

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

#                                                                              #
# ---------------------------------------------------------------------------- #

ct_main "$@"

# vim: set ft=sh noet ts=2 sw=2 :
