#!/bin/bash

echo "- deploying..."
source .include.common.sh

(
   cd "$(dirname "$0")"
   pwd
#   git branch -r -v
   GIT_CLONE_URL=$(git ls-remote --get-url origin)

   # tag to hash
   declare -A tag_hash
   for tag in $(git tag)
   do
      tag_hash[$(git rev-list -n 1 ${tag})]="${tag}"
   done
   declare -p tag_hash

   T_DIR=$(mktemp -d)
   trap 'rm -Rf ${T_DIR}' EXIT
   mkdir "${T_DIR}/.dpkg-root"
   ( cd ${T_DIR} ; git clone ${GIT_CLONE_URL} )


   for branch in $(git branch -r | awk '{ print $1 }')
   do
      branch_type="feature"
      branch_hash="$(git rev-parse ${branch})"
      if [[ ${branch} =~ origin/main ]]
      then
         # unstable
         #echo "unstable: ${branch}"
         branch_type="unstable"
      elif [[ ${branch} =~ origin/release/ ]]
      then
         # stable
         #echo "stable: ${branch}"
         branch_type="stable"
      else
         # feature
         : #echo "feature: ${branch}"
         continue
      fi

      branch_name="${branch#*/}" ; branch_name=${branch_name//\//-}
      branch_tag=${tag_hash[${branch_hash}]:="none"}
      if [ "${branch_tag}" == "none" ]
      then
         branch_version="0.0.0"
         branch_tag="${branch_hash:0:7}-$(date +%s)"
      else
         branch_version="${branch_tag//v/}"
      fi
      echo "${branch_type} - ${branch_hash} - ${branch_name} - TAG[${branch_tag}] - VERSION[${branch_version}]"
      
      DPKG_BUILD_ROOT="${T_DIR}/.dpkg-root/${branch_hash}"
      mkdir -p "${DPKG_BUILD_ROOT}"

      ( 
         cd ${T_DIR}/* ; git checkout "${branch_hash}"
         if [ -r ".include.build.deb.sh" ]   
         then
            echo "- sourcing build..."
            source ".include.build.deb.sh"
            gen_control_file
            gen_rootfs
            find "${DPKG_BUILD_ROOT}"
            deb_name="${DEBIAN["Package"]}-${DEBIAN["Version"]}_${DEBIAN["Architecture"]}.deb"
            if dpkg -b "${DPKG_BUILD_ROOT}" "${T_DIR}/.dpkg-root/${deb_name}"
            then
               ls -al "${T_DIR}/.dpkg-root/${deb_name}"
               echo "DIST: ${DIST[${branch_type}.pool.${DEBIAN["Architecture"]}]}"

               mv -v "${T_DIR}/.dpkg-root/${deb_name}" \
                     "${DIST["root"]}/${DIST[${branch_type}.pool.${DEBIAN["Architecture"]}]}/."

               # remove old versions if unstable
               if [ "${branch_type}" == "unstable" ]
               then
                  search_name="${deb_name}"
#                  echo "${search_name%-*}"
                  echo "- remove all unstable without latest hash"
                  # remove all not latest unstable
                  find "${DIST["root"]}/${DIST[${branch_type}.pool.${DEBIAN["Architecture"]}]}/." -type f ! -name "${search_name%-*}*.deb" -print0 \
                  | xargs -0 -n1 rm -fv
                  # only keep oldest with the same hash
                  echo "- keep oldest with latest hash"
                  find "${DIST["root"]}/${DIST[${branch_type}.pool.${DEBIAN["Architecture"]}]}/." -type f -name "${DEBIAN["Package"]}*.deb" \
                  | sort -n | tail -n +2 | xargs -n1 rm -rvf
               fi
            fi
         fi
      )

   done

)

