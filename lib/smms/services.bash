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
		echo "${line}" | grep -q "$2" && echo "${line}" | awk '{print $2}'
	done

	# Need for continue normal process
	echo
}

SMMS_SERVICE() {
	local cmd service
	cmd="$2"
	service="$(SMMS_SERVICE_MAIN "$1" "$3")"

	case "$(InitSystem)" in
	"${SMMS_INIT_OPENRC}")
		print_info "${SMMS_OPENRC_PATH}/${service} ${cmd}"
		${SMMS_OPENRC_PATH}/${service} ${cmd} && return
		print_warn "Error in service $2 after run command $1"
		;;
	"${SMMS_INIT_SYSTEMD}")
		print_info "systemctl ${service} ${cmd}"
		systemctl ${cmd} ${service} && return
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
