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

SMMS_SERVICE() {
	case "$(InitSystem)" in
	"${SMMS_INIT_OPENRC}")
		${SMMS_OPENRC_PATH}/$2 $1 && return
		print_warn "Error in service $2 after run command $1"
		;;
	"${SMMS_INIT_SYSTEMD}")
		systemctl $1 $2 && return
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
