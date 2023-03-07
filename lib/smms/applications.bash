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

SMMS_APLICATIONS=()
for app in ${SMMS_ROOT}/libexec/smms/applications/*; do
	SMMS_APLICATIONS+=( "$(basename "${app}")" )
	source "${app}"
done

unset app
