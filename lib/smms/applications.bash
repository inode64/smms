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

SMMS_APPLICATIONS=()
for app in ${SMMS_ROOT}/libexec/smms/applications/*; do
	SMMS_APPLICATIONS+=("$(basename "${app}")")
	# shellcheck source=libexec/smms/applications/${app}
	source "${app}"
done

unset app
