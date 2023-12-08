#!/bin/bash

# (c)opyright by hastmu@gmx.net 
# checkout https://github.com/hastmu/apt-proxy-detect
# v1 ... pure detect
# v2 ... cache value with check

function check_proxy() {
   wget -e http_proxy=$1 -e https_proxy=$1 -qO - $2 >> /dev/null
   return $?
}

cache_file="/tmp/.apt-proxy.$(id -un)"
touch ${cache_file} >> /dev/null 2>&1
skip_cache=0
if [ "$(stat -c %u ${cache_file})" != "$(id -u)" ]
then
   skip_cache=1
   echo "E: wrong owner of cache file ${cache_file}, remove or reown to $(id -un)" >&2
fi
service_name="_apt_proxy._tcp"
[ -z "$1" ] && testurl="http://deb.debian.org/debian" || testurl="$1"

if [ -s "${cache_file}" ] && [ ${skip_cache} -eq 0 ]
then
   proxy="$(cat ${cache_file})"
   if check_proxy "${proxy}" "${testurl}"
   then
      echo "${proxy}"
      exit 0
   else
      rm -f "${cache_file}"
   fi
fi

T_FILE=$(mktemp)
trap 'rm -f ${T_FILE}' EXIT
avahi-browse -tcpr ${service_name} > ${T_FILE}
if [ ! -s "${T_FILE}" ]
then
   # non cached
   avahi-browse -tpr ${service_name} > ${T_FILE}
fi

for service in $(cat ${T_FILE} | grep "^+;")
do
   name="$(echo ${service} | cut -d\; -f4 | sed 's:\\032: :g')"
   namef="$(echo ${service} | cut -d\; -f4)"
   proxy="http://$(cat ${T_FILE} | grep "^=" | grep "$(echo ${namef} | sed 's:\\:\\\\:g')" | cut -d\; -f8,9 | tr ";" ":")"
   if check_proxy ${proxy} ${testurl}
   then
      # ok 
      if [ -z "${ret}" ]
      then
         ret="${proxy}"
         if [ ${skip_cache} -eq 0 ] 
         then
            echo "${proxy}" > ${cache_file}
         fi
      fi
      stat="OK"
   else
      stat="ER"
   fi
   printf "Service[%s][%s]@%s \n" "${stat}" "${name}" "${proxy}" >&2
done

echo "${ret}"
