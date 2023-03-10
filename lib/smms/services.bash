#!/usr/bin/env bash

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
		test -x /etc/init.d/$1 && return
		;;
	"${SMMS_INIT_SYSTEMD}")
		test -e /lib/systemd/system/$1 && return
		;;
	esac

	return 1
}

SMMS_SERVICE() {
	case "$(InitSystem)" in
	"${SMMS_INIT_OPENRC}")
		/etc/init.d/$2 $1 && return
		;;
	"${SMMS_INIT_SYSTEMD}")
		systemctl $1 $2 && return
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
