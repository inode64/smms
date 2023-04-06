#!/usr/bin/env bash

SMMS_APPLICATIONS=()
for app in ${SMMS_ROOT}/libexec/smms/applications/*; do
	SMMS_APPLICATIONS+=("$(basename "${app}")")
	# shellcheck source=libexec/smms/applications/${app}
	source "${app}"
done

unset app

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

applications_check_lib() {
	[[ "$1" == "$2" ]] && return 1

	ldd "$1" 2>/dev/null | grep -q "$2"
}

applications_cmd_monit() {
	local name cmd group text lib

	cmd="$1"
	group="$2"
	name="$3"

	[[ ! "${name}" ]] && name=$(echo "${FUNCNAME[1]}" | cut -d_ -f1)

	text="
check file ${name}_bin with path ${cmd}
    group ${group}
    if changed checksum then restart
"

	# Search for libs dependencies
	for app in "${SMMS_APPLICATIONS[@]}"; do
		if FNExists "${app}_application_lib"; then
			lib="$(${app}_application_list)"
			if [[ "$lib" ]]; then
				applications_check_lib "${cmd}" "${lib}" && text="${text}""$(MonitMakeDeps ${app})"
			fi
		fi
	done

	MonitMakeFile "${text}" "${SMMS_APPLICATION}" "${name}"
}
