#!/bin/bash

declare -A DEBIAN

DEBIAN["Package"]="apt-proxy-detect"
DEBIAN["Version"]="${branch_version}-${branch_name}-${branch_tag}"
DEBIAN["Section"]="base"
DEBIAN["Priority"]="optional"
DEBIAN["Architecture"]="all"
DEBIAN["Depends"]="coreutils, grep, sed, wget, avahi-utils"
DEBIAN["Conflict"]="squid-deb-proxy-client"
DEBIAN["Maintainer"]="nomail@nomail.no"
DEBIAN["Description"]="apt proxy detection"

function gen_control_file() {

   local item=""
   mkdir -p "${DPKG_BUILD_ROOT}/DEBIAN"
   touch "${DPKG_BUILD_ROOT}/DEBIAN/control"
   for item in "${!DEBIAN[@]}"
   do
      echo "${item}: ${DEBIAN[${item}]}" >> "${DPKG_BUILD_ROOT}/DEBIAN/control"
   done

}

function gen_rootfs() {

   # create dirs
   mkdir -p "${DPKG_BUILD_ROOT}/usr/local/bin"
   mkdir -p "${DPKG_BUILD_ROOT}/etc/apt/apt.conf.d"

   # copy files
   cp -av apt-proxy-detect.sh "${DPKG_BUILD_ROOT}/usr/local/bin/."

   # create files
   # shellcheck disable=SC2140
   echo "Acquire::http::ProxyAutoDetect \""/usr/local/bin/apt-proxy-detect.sh"\";" > "${DPKG_BUILD_ROOT}/etc/apt/apt.conf.d/30apt-proxy-detect.conf"
   # shellcheck disable=SC2140
   echo "Acquire::https::ProxyAutoDetect \""/usr/local/bin/apt-proxy-detect.sh"\";" >> "${DPKG_BUILD_ROOT}/etc/apt/apt.conf.d/30apt-proxy-detect.conf"

   # set permissions
   chmod -R a+rx "${DPKG_BUILD_ROOT}"
   chmod -R a-x  "${DPKG_BUILD_ROOT}/etc/apt/apt.conf.d/30apt-proxy-detect.conf"

}




if [ 1 -eq 0 ]
then
   # defaults

   DPKG_NAME="${NAME}_${VERSION}_${BRANCH//\//-}_${HEADHASH}.deb"
   if dpkg -b "${T_DIR}" "${DPKG_NAME}"
   then
      apt-cache show "$(pwd)/${DPKG_NAME}"
      apt-get install --allow-downgrades -y "$(pwd)/${DPKG_NAME}"
      rm -fv "$(pwd)/${DPKG_NAME}"
      dpkg -l "${NAME}"
   fi

fi