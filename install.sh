#!/bin/bash

# check requirements
declare -A BINS
BINS["id"]=0
BINS["wget"]=0
BINS["touch"]=0
BINS["stat"]=0
BINS["avahi-browse"]=0
BINS["cat"]=0
BINS["sed"]=0
BINS["grep"]=0
BINS["cut"]=0
BINS["["]=0
BINS["printf"]=0
BINS["date"]=0
BINS["md5sum"]=0

for pitem in ${PATH//:/ }
do
    for item in "${!BINS[@]}"
    do
        if [ -x "${pitem}/${item}" ]
        then 
            BINS[${item}]="${pitem}/${item}"
        fi        
    done
done

#declare -p BINS
declare -i notfound=0
echo "- check dependencies..."
for item in "${!BINS[@]}"
do
    if [ "${BINS[${item}]}" = "0" ]
    then 
        echo "! not found: ${item}"
        notfound=1
    fi        
done
[ ${notfound} -eq 1 ] && exit 1

TARGET="/usr/local/bin/apt-proxy-detect.sh"
# download latest
echo "- download latest to: ${TARGET}"


echo "- BRANCH [${BRANCH:=main}]"
if ! wget -q -O "${TARGET}" https://raw.githubusercontent.com/hastmu/apt-proxy-detect/${BRANCH}/apt-proxy-detect.sh
then
   echo "- download failed."
   [ -x "${TARGET}" ] && rm -f "${TARGET}"
   exit 1
fi
echo "- set permissions to a+rx"
chmod a+rx "${TARGET}"

# install apt conf
NAME="apt-proxy-detect"
# shellcheck disable=SC2027
echo "Acquire::http::ProxyAutoDetect \""${TARGET}"\";" > /etc/apt/apt.conf.d/30${NAME}.conf
echo "- create/updating /etc/apt/apt.conf.d/30${NAME}.conf"



