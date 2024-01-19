#!/bin/bash

# defaults
echo "- BRANCH [${BRANCH:=main}]"
NAME="apt-proxy-detect"
VERSION="1.0.0"
HEADHASH="$(date +%s)"
TARGET="/usr/local/bin/${NAME}.sh"
APT_CONFIG_NAME="/etc/apt/apt.conf.d/30${NAME}.conf"

# workdir
T_DIR=$(mktemp -d)
trap 'rm -Rf "${T_DIR}"' EXIT

# create debian structure
# TODO get metric information out of github.
(
    cd "${T_DIR}" || exit
    mkdir DEBIAN
    cat <<EOF > DEBIAN/control
Package: ${NAME}
Version: ${VERSION}-${BRANCH}-${HEADHASH}
Section: base 
Priority: optional 
Architecture: all 
Depends: coreutils, grep, sed, wget, avahi-utils
Conflict: squid-deb-proxy-client
Maintainer: nomail@nomail.no
Description: apt proxy detection
EOF

    # main program
    mkdir -p "${T_DIR}$(dirname "${TARGET}")"
    echo -n "- downloading ... "
    if ! wget -q -O "${T_DIR}${TARGET}" "https://raw.githubusercontent.com/hastmu/apt-proxy-detect/${BRANCH}/apt-proxy-detect.sh"
    then
        echo "failed."
        exit 1
    else
        echo "ok."
        chmod a+rx "${T_DIR}${TARGET}"
    fi

    # apt config
    mkdir -p "${T_DIR}$(dirname "${APT_CONFIG_NAME}")"
    # shellcheck disable=SC2027
    echo "Acquire::http::ProxyAutoDetect \""${TARGET}"\";" > "${T_DIR}${APT_CONFIG_NAME}"

)

if dpkg -b "${T_DIR}" "${NAME}_${VERSION}_${HEADHASH}.deb"
then
   apt-get install -y "$(pwd)/${NAME}_${VERSION}_${HEADHASH}.deb"
   dpkg -l "${NAME}"
fi

