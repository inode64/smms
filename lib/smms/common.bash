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

declare -r SMMS_MONIT="/etc/monit.d"
declare -r SMMS_MONIT_APP="${SMMS_MONIT}/applications"
declare -r SMMS_MONIT_SRV="${SMMS_MONIT}/services"

declare -r SMMS_APPLICATION="application"
declare -r SMMS_SERVICE="service"

# cannot ->, are shown in: ntpupdate, mdadm
declare -r SMS_WARNING1="cannot \|deprecated\|failed\|linked\|not loaded\|warn:\|warning"
# Disk fail in smart
declare -r SMS_ERROR1="BACK UP DATA NOW"

SMS_PIPE_STDERR="$(mktemp -u /tmp/XXXXXX)"
SMS_PIPE_STDOUT="$(mktemp -u /tmp/XXXXXX)"

declare -r SMS_PIPE_STDERR
declare -r SMS_PIPE_STDOUT

trap 'rm -f "${SMS_PIPE_STDERR}" "${SMS_PIPE_STDOUT}"' EXIT

mkfifo "${SMS_PIPE_STDERR}"
mkfifo "${SMS_PIPE_STDOUT}" 2>/dev/null

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
	echo "$(pgrep -f "$1")"
}

WHICH() {
	local exec=$1

	if [ "${exec:0:1}" == "=" ]; then
		echo "${exec:1}"
		return
	fi

	exec=$(which "${exec}" 2>/dev/null)

	if [ ! "${exec}" ]; then
		exec=$(which "$(basename "$1")" 2>/dev/null)
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

NCPU() {
	grep -c processor /proc/cpuinfo
}

CPU_Alert() {
	local result

	((result = 92 / $(NCPU)))
	echo "${result}%"
}

CPU_Warning() {
	local result

	((result = 65 / $(NCPU)))
	echo "${result}%"
}

MEM_Alert() {
	echo "40%"
}

MEM_Warning() {
	echo "20%"
}

InitSystem() {
	if test -d /run/systemd/system; then
		echo ${SMMS_INIT_SYSTEMD}
	fi

	if test -d /run/openrc; then
		echo ${SMMS_INIT_OPENRC}
	fi
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
	echo "$1" | grep -o "\([0-9]\)\?\(\(\.[0-9]\+\)\?\(\.[0-9]\+\)\)\?" | head -1
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
	local args cmd name type

	name=$(echo "${FUNCNAME[1]}" | cut -d_ -f1)
	type=$(echo "${FUNCNAME[1]}" | cut -d_ -f2)
	cmd=$(echo "${FUNCNAME[1]}" | cut -d_ -f3)
	args="$1"

	[[ "${debug:?}" = 'true' ]] && print_info "${FUNCNAME[1]} from ${FUNCNAME[2]}: entering function, parameters: ${args}"

	[[ "${type}" != "${SMMS_APPLICATION}" ]] && [[ "${type}" != "${SMMS_SERVICE}" ]] && Fatal "The name of the function does not comply with the standard ${name}_${type}"
	[[ ! "${cmd}" ]] && Fatal "The name of the function does not comply with the standard ${name}_${type}"

	if [[ "${type}" == "${SMMS_APPLICATION}" ]]; then
		if [[ "${cmd}" == "status" ]] || [[ "${cmd}" == "version" ]]; then
			[[ ! "${args}" ]] && Fatal "The function ${name}_${type}_${cmd} need parameter"
			check_list "${name}" "${type}" "${args}"
		fi
	fi

	if [[ "${type}" == "${SMMS_SERVICE}" ]]; then
		if [[ "${cmd}" == "info" ]] || [[ "${cmd}" == "process" ]] || [[ "${cmd}" == "status" ]]; then
			[[ ! "${args}" ]] && Fatal "The function ${name}_${type}_${cmd} need parameter"
			check_list "${name}" "${type}" "${args}"
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

	$(WHICH monit) status $1 &>/dev/null
}

MonitMakeDeps() {
	local name

	name="$1"

	echo "    depends on ${name}_bin"
}

MonitMakeFile() {
	local name type text file

	text="$1"
	type="$2"
	name="$3"

	[[ ! "${text}" ]] && return

	[[ ! "${name}" ]] && name=$(echo "${FUNCNAME[1]}" | cut -d_ -f1)
	[[ ! "${type}" ]] && type=$(echo "${FUNCNAME[1]}" | cut -d_ -f2)

	case "${type}" in
	"${SMMS_APPLICATION}")
		test -e "${SMMS_MONIT_APP}.local/${name}" && return
		file="${SMMS_MONIT_APP}/${name}"
		;;
	"${SMMS_SERVICE}")
		test -e "${SMMS_MONIT_SRV}.local/${name}" && return
		file="${SMMS_MONIT_SRV}/${name}"
		;;
	*)
		Fatal "This function can only be used from functions of applications or services."
		;;
	esac

	text="${text//\{NCPU\}/$(NCPU)}"
	text="${text//\{CPU_ALERT\}/$(CPU_Alert)}"
	text="${text//\{CPU_WARNING\}/$(CPU_Warning)}"

	text="${text//\{MEM_ALERT\}/$(MEM_Alert)}"
	text="${text//\{MEM_WARNING\}/$(MEM_Warning)}"

	echo -e "${text}"
}

FNExists() {
	[[ $(type -t "$1") == function ]]
}

CheckTMPL() {
	local name type model

	model="$1"
	type="$2"
	name="$3"

	[[ ! "${name}" ]] && name=$(echo "${FUNCNAME[1]}" | cut -d_ -f1)
	[[ ! "${type}" ]] && type=$(echo "${FUNCNAME[1]}" | cut -d_ -f2)

	[[ ! -e "$SMMS_ROOT/libexec/smms/${type}s/tmpl/${model}/${name}" ]] && return 1

	cat "$SMMS_ROOT/libexec/smms/${type}s/tmpl/${model}/${name}"
}
