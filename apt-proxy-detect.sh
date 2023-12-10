#!/bin/bash

# (c)opyright by gh-hastmu@gmx.de
# checkout https://github.com/hastmu/apt-proxy-detect
# v1 ... pure detect
# v2 ... cache value with check
# v3 ... add persistant caching for found proxies.

declare -i debug
[ -z "${DEBUG_APT_PROXY_DETECT}" ] && debug=0 || debug=1

if [ $debug -eq 0 ]
then
   function debug() { 
      :
   }
else 
   function debug() {
      printf "[%10s]: %s\n" "$1" "$2" >&2
   }
fi
debug "INFO" "apt-proxy-detect"

function check_proxy() {
   wget -e "http_proxy=$1" -e "https_proxy=$1" -qO - "$2" >> /dev/null
   return $?
}

# cache file name
cache_file_name=".apt-proxy-detect.$(id -un)"

# persistant cache file location
# $HOME or special for system accounts
declare -A CACHE_FILE_LOC
CACHE_FILE_LOC["_apt"]="/var/lib/apt/lists/auxfiles/${cache_file_name}"

if [ -n "${CACHE_FILE_LOC[$(id -un)]}" ]
then
   cache_file="${CACHE_FILE_LOC[$(id -un)]}"
else
   if [ -w "${HOME}/.config/." ]
   then
      cache_file="${HOME}/.config/${cache_file_name}"
   else
      cache_file="/tmp/${cache_file_name}"
   fi
fi

# check cache_file
touch "${cache_file}" >> /dev/null 2>&1

skip_cache=0
if [ "$(stat -c %u "${cache_file}")" != "$(id -u)" ]
then
   skip_cache=1
   echo "E: wrong owner of cache file ${cache_file}, remove or reown to $(id -un)" >&2
fi
service_name="_apt_proxy._tcp"
[ -z "$1" ] && testurl="http://deb.debian.org/debian" || testurl="$1"
debug "TEST-URL" "URL: ${testurl}"

if [ -s "${cache_file}" ] && [ ${skip_cache} -eq 0 ]
then
   debug "CACHE" "using stored under: ${cache_file}"
   proxy="$(cat "${cache_file}")"
   debug "CHECK" "Checking cached proxy (${proxy}) with testurl (${testurl})"
   if check_proxy "${proxy}" "${testurl}"
   then
      debug "WORKS" "give back cached proxy"
      debug "PROXY" "return ${proxy}"
      echo "${proxy}"
      exit 0
   else
      debug "FAILED" "remove cache file."
      rm -f "${cache_file}"
   fi
fi

T_FILE=$(mktemp)
trap 'rm -f ${T_FILE}' EXIT
debug "AVAHI" "get cache entries for ${service_name}"
avahi-browse -tcpr ${service_name} > "${T_FILE}"
if [ ! -s "${T_FILE}" ]
then
   # non cached
   debug "AVAHI" "get non-cache entries for ${service_name}"
   avahi-browse -tpr ${service_name} > "${T_FILE}"
fi

# shellcheck disable=SC2013
for service in $(grep "^+;" "${T_FILE}")
do
   name="$(echo "${service}" | cut -d\; -f4 | sed 's:\\032: :g')"
   namef="$(echo "${service}" | cut -d\; -f4)"
   proxy="http://$(grep "^=" "${T_FILE}" | grep "${namef//\\/\\\\}" | cut -d\; -f8,9 | tr ";" ":")"
   debug "CHECK" "Checking found proxy (${proxy}) with testurl (${testurl})"
   if check_proxy "${proxy}" "${testurl}"
   then
      # ok 
      if [ -z "${ret}" ]
      then
         ret="${proxy}"
         if [ ${skip_cache} -eq 0 ] 
         then
            debug "CACHE" "Store (${proxy}) in cache file (${cache_file})"
            echo "${proxy}" > "${cache_file}"
         fi
      fi
      stat="OK"
   else
      stat="ER"
   fi
   printf "Service[%s][%s]@%s \n" "${stat}" "${name}" "${proxy}" >&2
done

debug "PROXY" "return ${ret}"
if [ -n "${ret}" ]
then
   echo "${ret}"
fi
exit 0
