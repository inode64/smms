#!/usr/bin/env bash

declare -r SMMS_OPENRC_PATH="/etc/init.d"
declare -r SMMS_SYSTEMD_PATH="/lib/systemd/system"

declare -r SMMS_SERVICE_CMD="${SMMS_ROOT}/smms-service"

SMMS_SERVICES=()
for service in ${SMMS_ROOT}/libexec/smms/services/*; do
	[[ ! -f ${service} ]] && continue
	SMMS_SERVICES+=("$(basename "${service}")")
	# shellcheck source=libexec/smms/services/${service}
	source "${service}"
done

unset service

SMMS_SERVICE_EXIXTS() {
	case "$(InitSystem)" in
	"${SMMS_INIT_OPENRC}")
		test -x "${SMMS_OPENRC_PATH}/$1" && return
		;;
	"${SMMS_INIT_SYSTEMD}")
		test -e "${SMMS_SYSTEMD_PATH}/$1" && return
		;;
	esac

	return 1
}

SMMS_SERVICE_MAIN() {
	${1}_service_list | while read -r line; do
		echo "${line}" | grep -q "$2" && echo "${line}" | awk '{print $1}'
	done

	# Need for continue normal process
	echo
}

SMMS_SERVICE() {
	local cmd service

	cmd="$2"
	service="$(SMMS_SERVICE_MAIN "$1" "$3")"

	([[ $(MonitStatus "${service}") ]] && [[ ! $(CallFromMonit) ]]) && ([[ "${cmd}" == "stop" ]] || [[ "${cmd}" == "start" ]]) && (
		[[ "${debug:?}" = 'true' ]] && print_info "Exec into monit"
		$(WHICH "monit") "${cmd}" "${service}"
	) || (
		SMMS_SERVICE_CMD $1 $2 $3

		[[ "${cmd}" == "stop" ]] && [[ "$(InitSystem)" == "${SMMS_INIT_OPENRC}" ]] && run_cmd "${SMMS_OPENRC_PATH}/${service}" zap

		[[ "${cmd}" == "stop" ]] && SMMS_SERVICE_KILL "$1" "$3"
	)
}

SMMS_SERVICE_CMD() {
	local cmd service args

	cmd="$2"
	service="$(SMMS_SERVICE_MAIN "$1" "$3")"

	case "$(InitSystem)" in
	"${SMMS_INIT_OPENRC}")
		[[ "${deps:?}" = 'true' ]] && args=" --nodeps"
		run_cmd "${SMMS_OPENRC_PATH}/${service}" "${args}" "${cmd}" && return
		print_warn "Error in service $2 after run command $1"
		# always zap openrc service after stop in error case, after we kill all process
		[[ "${cmd}" == "stop" ]] && run_cmd "${SMMS_OPENRC_PATH}/${service}" zap
		;;
	"${SMMS_INIT_SYSTEMD}")
		[[ "${deps:?}" = 'true' ]] && args=" --job-mode=ignore-requirements"
		run_cmd systemctl "${args}" "${cmd}" "${service}" && return
		print_warn "Error in service $2 after run command $1"
		;;
	esac

	return 1
}

SMMS_SERVICE_LIST() {
	local s

	for s in $(${1}_service_list); do
		test "$s" == "$2" && return
	done

	return 1
}

SYSTEMD_SERVICE_ALIAS() {
	local alias

	echo "$1" | grep -q "\.\(target\|socket\|timer\|wants\|mount\|path\|slice\|automount\)$" && (
		echo -n "$1"
		return
	)

	alias=${1/\.service/}
	echo "$1" | grep -q "\.service$" && echo -n "$1 ${alias}" || echo -n "$1.service ${alias}"
}

# order - arg1
# systemd - arg2
# openrc - arg3
# ... - arg*
SMMS_SERVICE_ORDER() {
	local init systemd w w1 ws string

	systemd=$(SYSTEMD_SERVICE_ALIAS "$2")
	init=$1
	declare -a string=()

	shift
	shift

	case "$init" in
	"${SMMS_INIT_OPENRC}")
		ws="$* ${systemd}"
		;;
	"${SMMS_INIT_SYSTEMD}")
		ws="${systemd} $*"
		;;
	esac

	for w in ${ws}; do
		for w1 in "${string[@]}"; do
			[[ "${w1}" == "${w}" ]] && continue 2
		done
		# only insert the unique words
		string+=("$w")
	done

	echo "${string[@]}"
}

SMMS_SERVICE_KILL() {
	local p pids s try

	s=$1
	p=$2
	try=4

	while true; do
		[[ "${debug:?}" = 'true' ]] && print_info "Try ${try}, kill process: ${p}"

		pids=$(${s}_service_process "${p}")
		# check if all process are stopped
		[[ ! "${pids}" ]] && return

		sleep 1

		pids=$(${s}_service_process "${p}")
		[[ ! "${pids}" ]] && return

		[[ "${debug:?}" = 'true' ]] && print_info "Kill process: ${p}, $(ps ${pids//[$'\t\r\n']/ })"

		kill ${pids}

		((--try)) || break
	done

	# Force kill process
	pids=$(${s}_service_process "${p}")
	[[ ! "${pids}" ]] && return

	[[ "${debug:?}" = 'true' ]] && print_info "Kill -9 process: ${p}, $(ps ${pids//[$'\t\r\n']/ })"

	kill -9 ${pids}
}

SMMS_SERVICE_INIT() {
	local init systemd openrc

	systemd="$1"
	openrc="$2"
	init="$(InitSystem)"

	case "${init}" in
	"${SMMS_INIT_OPENRC}")
		test -x "${SMMS_OPENRC_PATH}/${openrc}" && SMMS_SERVICE_ORDER "${init}" "${systemd} ${openrc}"
		;;
	"${SMMS_INIT_SYSTEMD}")
		test -e "${SMMS_SYSTEMD_PATH}/${systemd}" && SMMS_SERVICE_ORDER "${init}" "${systemd} ${openrc}"
		;;
	esac
}

SMMS_SERVICE_DEPS() {
	echo "depends on php$(getVersion "${name}")_bin"
}