#!/usr/bin/env bash

export SMMS_VERSION='0.1.0'

export SMMS_INIT_SYSTEMD="systemd"
export SMMS_INIT_OPENRC="openrc"

SMMS_OS_ALPINE="alpine"
SMMS_OS_ARCH="arch"
SMMS_OS_CENTOS="centos"
SMMS_OS_DEBIAN="debian"
SMMS_OS_GENTOO="gentoo"
SMMS_OS_REDHAT="redhat"
SMMS_OS_SUSE="suse"
SMMS_OS_UBUNTU="ubuntu"

getDistro() {
	cat /etc/*-release 2>/dev/null | tr "[:upper:]" "[:lower:]" | grep -Poi '(alpine|arch|centos|debian|gentoo|redhat|suse|ubuntu)' | uniq
}

IsRunning() {
	pgrep -c "$1" 2>/dev/null

	return $?
}

PIDS() {
	# Remove carriage returns, tabs and multiple spaces
	# shellcheck disable=SC2005
	echo "$(pgrep -f "${1}")"
}

WHICH() {
	local exec=$1

	if [ "${exec:0:1}" == "=" ]; then
		echo "${exec:1}"
		return
	fi

	exec=$(which "${exec}" 2>/dev/null)

	if [ ! "${exec}" ]; then
		exec=$(which "$(basename "${1}")" 2>/dev/null)
		if [ "${exec}" ]; then
			echo "${exec}"
			return
		fi
		echo "$1"
		return
	fi

	echo "${exec}"
}

IsMounted() {
	local dir

	dir=$(echo "$1" | sed -e 's: :\\\\\\\\040:g')
	grep -q "^.* ${dir} " /proc/mounts

	return $?
}

AddLock() {
	local dir

	dir=$(echo "$1" | sed -e 's:/:_:g' | sed -e 's: :_:g')
	local count
	local dst=${LOCK}/${dir}

	((count = $(cat "${dst}" 2>/dev/null) + 1)) || true
	echo ${count} >"${dst}"

	return ${count}
}

SetLock() {
	local dir

	dir=$(echo "$1" | sed -e 's:/:_:g' | sed -e 's: :_:g')
	local count=$2
	local dst=${LOCK}/${dir}

	echo "$count" >"${dst}"

	return "${count}"
}

RemoveLock() {
	local dir

	dir=$(echo "$1" | sed -e 's:/:_:g' | sed -e 's: :_:g')
	local count
	local dst=${LOCK}/${dir}

	((count = $(cat "${dst}" 2>/dev/null) - 1)) || true
	if [[ $count -lt 0 ]]; then
		count=0
	fi
	echo $count >"${dst}"

	return "${count}"
}

Ncpu() {
	grep -c processor /proc/cpuinfo
}

InitSystem() {
	if test -d /run/systemd/system; then
		echo ${SMMS_INIT_SYSTEMD}
	fi

	if test -d /run/openrc; then
		echo ${SMMS_INIT_OPENRC}
	fi

	return
}

print_info() { [ -n "${NO_STDOUT+x}" ] || printf "${COLOR_RESET-}[${COLOR_BGREEN-}INFO${COLOR_RESET-}] %s\n" "${@-}"; }
print_warn() { [ -n "${NO_STDERR+x}" ] || printf "${COLOR_RESET-}[${COLOR_BYELLOW-}WARN${COLOR_RESET-}] %s\n" "${@-}" >&2; }
print_error() { [ -n "${NO_STDERR+x}" ] || printf "${COLOR_RESET-}[${COLOR_BRED-}ERROR${COLOR_RESET-}] %s\n" "${@-}" >&2; }
print_list() { [ -n "${NO_STDOUT+x}" ] || printf "${COLOR_RESET-} ${COLOR_BCYAN-}*${COLOR_RESET-} %s\n" "${@-}"; }

Fatal() {
	print_error "$*"
	exit 1
}

getVersion() {
	echo "$1" | grep -o "\([1-9]\)\?\(\(\.[0-9]\+\)\?\(\.[0-9]\+\)\)\?"
}

falsetrue() {
	[[ "$1" == "0" ]] && echo "True" || echo "False"
}

check_program() {
	local cmd err
	cmd=$(WHICH "$1")
	test -x "${cmd}"
	err=$?
	if [ "${debug:?}" = 'true' ]; then
		if [[ "${err}" == "0" ]]; then
			print_info "Check program $1 -> ${cmd} with result $(falsetrue ${err})" >&2
		else
			print_info "Check program ${cmd} with result $(falsetrue ${err})" >&2
		fi
	fi
	return ${err}
}
