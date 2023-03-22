#!/usr/bin/env bash

applications_version() {
	$(WHICH "$1") --version
}

applications_v() {
	$(WHICH "$1") -v
}

applications_vv() {
	$(WHICH "$1") -V
}

applications_status() {
	applications_version "$1" &>/dev/null
}

applications_cmd_monit() {
	local name cmd group

	name="$1"
	cmd="$2"
	group="$3"

	cat << EOF
check file ${name}_bin with path ${cmd}
    group ${group}
    if changed checksum then restart
EOF
}

SMMS_APPLICATIONS=()
for app in ${SMMS_ROOT}/libexec/smms/applications/*; do
	SMMS_APPLICATIONS+=("$(basename "${app}")")
	# shellcheck source=libexec/smms/applications/${app}
	source "${app}"
done

unset app
