#!/bin/bash

# (c)opyright by gh-hastmu@gmx.de
# checkout https://github.com/hastmu/apt-proxy-detect
# v1 ... pure detect
# v2 ... cache value with check
# v3 ... add persistant caching for found proxies.
# v4 ... extend caching to also cache no-found proxy state 
#        and proxy checking based on testurl
#        + debug reveals ms execution time
#        + timeout for check_proxy
#        + cache age per entry not per whole file.
#        TODO: cache leading url not full, as i get called for all packages also.


# defaults
service_name="_apt_proxy._tcp"
cache_file_name=".apt-proxy-detect.$(id -un)"
cache_file_none_retry_timeout=60 
declare -i cache_age=0

declare -A CACHED_PROXIES
declare -A CACHED_PROXIES_AGE

declare -i debug
[ -z "${DEBUG_APT_PROXY_DETECT}" ] && debug=0 || debug=1

if [ $debug -eq 0 ]
then
   function debug() { 
      :
   }
else 
   declare -i start_time=0
   start_time=$(date +%s%N)
   function debug() {
      printf "[%12s][%4s]: %s\n" "$1" "$(( ($(date +%s%N) - start_time) / 1000000 ))" "$2" >&2
   }
fi
debug "INFO" "===--- apt-proxy-detect ---==="

function check_proxy() {
   if [ "$1" == "NONE" ]
   then
      if [ ${cache_age} -gt ${cache_file_none_retry_timeout} ]
      then
         debug "CHECK-PROXY" "NONE-cached expired" 
         return 1
      else
         debug "CHECK-PROXY" "NONE-cached" 
         return 0
      fi
   else
      debug "CHECK-PROXY" "Checking proxy (${1}) with testurl (${2})"
      if [ $debug -gt 1 ]
      then
         wget -v --tries=1 -T 1 -e "http_proxy=$1" -e "https_proxy=$1" -O - "$2" >&2
      else
         wget -q --tries=1 -T 1 -e "http_proxy=$1" -e "https_proxy=$1" -O - "$2" >> /dev/null 2>&1
      fi
      return $?
   fi
}

# --- cache location ---
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

# check cache_file if not there create it.
[ ! -e "${cache_file}" ] && touch "${cache_file}" >> /dev/null 2>&1

# check ownership of cache file and fetch age.
skip_cache=0
if [ "$(stat -c %u "${cache_file}")" != "$(id -u)" ]
then
   skip_cache=1
   echo "E: wrong owner of cache file ${cache_file}, remove or reown to $(id -un)" >&2
fi

# eval testurl
[ -z "$1" ] && testurl="http://deb.debian.org/debian" || testurl="$1"
debug "TEST-URL" "URL:  ${testurl}"
testurl_hash="$(echo "${testurl}" | md5sum)" ; testurl_hash="${testurl_hash%% *}"
debug "HASH" "HASH: ${testurl_hash}"

# check out cached value
if [ -s "${cache_file}" ] && [ ${skip_cache} -eq 0 ]
then
   # shellcheck disable=SC1090
   source "${cache_file}"
   # shellcheck disable=SC2181
   if [ $? -ne 0 ]
   then
      # something is wrong with the cache file remove it.
      debug "CACHE" "invalid cachefile (cleanup): ${cache_file}"
      rm -f "${cache_file}"
   else
      debug "CACHE" "using stored under: ${cache_file}"
   fi 
   cache_age=$(( $(date +%s) - ${CACHED_PROXIES_AGE[${testurl_hash}]:=0} ))
   debug "CACHE-AGE" "age: ${cache_age} sec"
   proxy="${CACHED_PROXIES[${testurl_hash}]}"
   if [ -n "${proxy}" ]
   then
      if check_proxy "${proxy}" "${testurl}"
      then
         debug "WORKS" "give back cached proxy"
         debug "PROXY" "return ${proxy}"
         [ "${proxy}" != "NONE" ] && echo "${proxy}"
         exit 0
      else
         debug "FAILED" "remove from cache file."
   #      declare -p CACHED_PROXIES >&2
         unset 'CACHED_PROXIES["${testurl_hash}"]'
         unset 'CACHED_PROXIES_AGE["${testurl_hash}"]'
   #      declare -p CACHED_PROXIES >&2
      fi
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
      fi
      stat="OK"
   else
      stat="ER"
   fi
   printf "Service[%s][%s]@%s \n" "${stat}" "${name}" "${proxy}" >&2
done

debug "PROXY" "return :${ret}:"

if [ -n "${ret}" ]
then
   echo "${ret}"
else
   ret="NONE"
fi

# write back cachefile finally.
if [ ${skip_cache} -eq 0 ] 
then
   debug "CACHE" "Store (${ret}) in cache file (${cache_file})"
   CACHED_PROXIES[${testurl_hash}]="${ret}"
   CACHED_PROXIES_AGE[${testurl_hash}]="$(date +%s)"
   debug "CACHE" "Update cachefile."
   declare -p CACHED_PROXIES > "${cache_file}"
   declare -p CACHED_PROXIES_AGE >> "${cache_file}"
fi

exit 0
