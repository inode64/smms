#!/usr/bin/env bash

export SMMS_VERSION='0.1.0'

export SMMS_INIT_SYSTEMD="systemd"
export SMMS_INIT_OPENRC="openrc"

declare -r SMMS_OS_ALPINE="alpine"
declare -r SMMS_OS_ARCH="arch"
declare -r SMMS_OS_CENTOS="centos"
declare -r SMMS_OS_DEBIAN="debian"
declare -r SMMS_OS_GENTOO="gentoo"
declare -r SMMS_OS_REDHAT="redhat"
declare -r SMMS_OS_SUSE="suse"
declare -r SMMS_OS_UBUNTU="ubuntu"

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

print_info() { [ -n "${NO_STDOUT+x}" ] || printf "${COLOR_RESET-}[${COLOR_BGREEN-}INFO${COLOR_RESET-}] %s\n" "${@-}" >&2; }
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

	[[ "${err}" == "0" ]] && echo "${cmd}"
}

entry_function() {
	[[ "${debug:?}" = 'true' ]] && print_info "${1} from ${2}: entering function, parameters: ${*:3}"

	local name type cmd
	name=$(echo "${1}" | cut -d_ -f1)
	type=$(echo "${1}" | cut -d_ -f2)
	cmd=$(echo "${1}" | cut -d_ -f3)

	[[ "${type}" != "application" ]] && [[ "${type}" != "service" ]] && Fatal "The name of the function does not comply with the standard ${name}_${type}"
	[[ ! "${cmd}" ]] && Fatal "The name of the function does not comply with the standard ${name}_${type}"

	if [[ "${type}" == "application" ]]; then
		if [[ "${cmd}" == "status" ]] || [[ "${cmd}" == "version" ]]; then
			[[ ! "${3}" ]] && Fatal "The function ${name}_${type}_${cmd} need parameter"
			check_list "${name}" "${type}" "${3}"
		fi
	fi

	if [[ "${type}" == "service" ]]; then
		if [[ "${cmd}" == "info" ]] || [[ "${cmd}" == "process" ]] || [[ "${cmd}" == "status" ]]; then
			[[ ! "${3}" ]] && Fatal "The function ${name}_${type}_${cmd} need parameter"
			check_list "${name}" "${type}" "${3}"
		fi
	fi
}

check_list() {
	local cmd name type result

	name=$1
	type=$2
	cmd=$3

	for result in $(${name}_${type}_list); do
		[[ "${result}" == "${cmd}" ]] && return 0
	done

	Fatal "Command ${cmd} not exits in ${name}_${type}"
}

run_cmd() {
	local cmd

	cmd=$(WHICH "$1")
	shift

	[[ "${debug:?}" = 'true' ]] && print_info "cmd: ${cmd} , args: $*"

	eval "${cmd}" "$*"
}

MonitExits() {
	local cmd
	cmd=$(WHICH "monit")

	test -x "${cmd}"
}

CallFromMonit() {
	MonitExits || return

	grep -aq "$(WHICH monit)" /proc/${PPID}/cmdline &>/dev/null && (
		[[ "${debug:?}" = 'true' ]] && print_info "Call from monit"
		return
	)

	return 1
}

MonitStatus() {
	MonitExits || return 1

	$(WHICH monit) status ${1} 2>/dev/null
}
