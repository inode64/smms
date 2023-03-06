#!/usr/bin/env bash

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
		echo "systemd"
	fi

	if test -d /run/openrc; then
		echo "openrc"
	fi

	return
}
