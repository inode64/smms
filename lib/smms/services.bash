#!/usr/bin/env bash

declare -r SMMS_OPENRC_PATH="/etc/init.d"
declare -r SMMS_SYSTEMD_PATH="/lib/systemd/system"

SMMS_SERVICES=()
for service in ${SMMS_ROOT}/libexec/smms/services/*; do
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

	[[ $(MonitStatus) ]] && ([[ "${cmd}" == "stop" ]] || [[ "${cmd}" == "start" ]]) && (
		$(WHICH "monit") "${cmd}" "${service}"
		return
	)

	SMMS_SERVICE_CMD $1 $2 $3

	[[ "${cmd}" == "stop" ]] && [[ "$(InitSystem)" == "${SMMS_INIT_OPENRC}" ]] && run_cmd "${SMMS_OPENRC_PATH}/${service}" zap
}

SMMS_SERVICE_CMD() {
	local cmd service
	cmd="$2"
	service="$(SMMS_SERVICE_MAIN "$1" "$3")"

	case "$(InitSystem)" in
	"${SMMS_INIT_OPENRC}")
		run_cmd "${SMMS_OPENRC_PATH}/${service}" "${cmd}" && return
		print_warn "Error in service $2 after run command $1"
		# always zap openrc service after stop in error case, after we kill all process
		[[ "${cmd}" == "stop" ]] && run_cmd "${SMMS_OPENRC_PATH}/${service}" zap
		;;
	"${SMMS_INIT_SYSTEMD}")
		run_cmd systemctl "${cmd}" "${service}" && return
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

		[[ "${debug:?}" = 'true' ]] && print_info "Kill process: ${p}, ${pids//[$'\t\r\n']/ }"

		kill ${pids}

		((--try)) || break
	done

	# Force kill process
	pids=$(${s}_service_process "${p}")
	[[ ! "${pids}" ]] && return

	[[ "${debug:?}" = 'true' ]] && print_info "Kill -9 process : ${p} , ${pids}"

	kill -9 ${pids}
}
