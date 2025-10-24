#!/usr/bin/env bash
# ---
# install:
#   - bash
#   - libnotify-bin
#   - mailutils

__mine=defaults.sh

__user="$(id -u)"
__path="$(realpath "$0")"
__base="$(dirname  "$__path")"
__exec="$(basename "$__path")"

if [ "${XDG_RUNTIME_DIR##*/}" = "${__user:?}" -a -d "$XDG_RUNTIME_DIR" ]; then
    __shm="$XDG_RUNTIME_DIR"
else
    if [ -d /run/shm ]; then
        __shm="/run/shm/$__mine.$__user"
    elif [ -d /dev/shm ]; then
        __shm="/dev/shm/$__mine.$__user"
    else
        __shm="/tmp/$__mine.$__user"
    fi
    mkdir -m 0700 -p "$__shm"
fi

__dump_error(){
    echo "
        [$(date '+%F %X'), from <$(id -un)@$(hostname)>]

        Print method "$1" failed with exit status "$2", output:
        $(cat "$__shm/$__mine.$$.dump")

        Message originally intended to be output from "$__exec":
        $3
    " | sed 's/^ \+//' |
        if [ "$1" = notify -o "$1" = push ]; then
            __print=email print
        else
            if [ ~user = '~user' ]; then
                tee -a ~/"$__mine.err"
            else
                tee -a ~user/"$__mine.err"
            fi >&2
        fi
}

print(){
    local _print _message

    if [ -n "${__print:-}" ]; then
        _print="$__print"
    else
        if tty --quiet; then
            _print=stderr
        else
            _print=email
        fi
    fi

    if [ -n "${1:-}" ]; then
        _message="$1"
    else
        _message="$(cat /dev/stdin)"
    fi

    if [ -z "${_message:-}" ]; then
        print "Usage: print message|stdin"
        exit 1
    fi

    if [ "$_print" = stderr ]; then
        echo "$_message" >&2
    else
        case "$_print" in
            notify)
                notify-send -u critical -i dialog-warning "$__exec" \
                    "$(echo "$_message" | head -c 1000 | fmt -suw 70)"
            ;;
            push)
                alias.push.sh warning "$(uname -n): $__exec" \
                    "$(echo "$_message" | head -c 1500)"
            ;;
            email)
                echo "$_message" | head -c 100000 |
                    mail -s "$(uname -n): $__exec" "$(</var/local/.mail)"
            ;;
        esac >"$__shm/$__mine.$$.dump" 2>&1 ||
            __dump_error "$_print" "$?" "$_message"
        rm -f "$__shm/$__mine.$$.dump"
    fi
}

if [ -z "$BASH" ]; then
    print "ERROR: sourced file \"$__mine\" requires bash."
    exit 1
fi

BASH_COMPAT=4.4

set -o errexit -o errtrace -o nounset

case "${1:-}" in
    print=stderr)
        __print=stderr
    ;;
    print=notify)
        __print=notify
    ;;
    print=push)
        __print=push
    ;;
    print=email)
        if [ -r /var/local/.mail -a -s /var/local/.mail ]; then
            __print=email
        else
            echo "WARNING: missing /var/local/.mail" >&2
        fi
    ;;
    ''|*)
        print "Usage: . $__mine print=[stderr|notify|push|email]"
        exit 1
    ;;
esac

if [[ "$__shm" =~ ^/tmp ]]; then
    print "WARNING: \"$__mine\" will fallback to \$__shm=$__shm for UID=$__user"
fi

command_not_found_handle(){
    if [[ "${FUNCNAME[1]}" = print ]]; then
        echo "Command \"$1\" is missing."
    else
        print "Command \"$1\" is missing."
    fi
    return 127
}

trap 'cat >"$__shm/$$.return" <<-EOF
	$BASH_SOURCE
	${BASH_SOURCE##*/}
	$LINENO
	$?
EOF' ERR

trace_exit(){
    set +o xtrace
    local _error

    if [[ -s "$__shm/$$.return" ]]; then
        mapfile -t _error <"$__shm/$$.return"
    else
        return 0
    fi

    case "${_error[3]}" in
        0|127|130|143)
        ;;
        *)
            print <<-EOF
				${_error[1]} returned status ${_error[3]} on line ${_error[2]}:
				+ $(awk "NR==${_error[2]}" "${_error[0]}")
			EOF
        ;;
    esac
}

trap_exit(){
    local _chomp

    if [[ ! "${1:-}" ]]; then
        print "Usage: $FUNCNAME command"
        exit 1
    fi

    _chomp="${1%$'\n'}"; __exit+="${_chomp%;}; "

    trap "{
        set +o errexit +o nounset
            $__exit
        set +o noglob
            rm -f '$__shm/$$'.*
    }" EXIT
}

trap_exit 'trace_exit; trap - ERR'
