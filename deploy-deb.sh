#!/bin/bash

echo "- deploying..."

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

      branch_tag=${tag_hash[${branch_hash}]:="none"}
      echo "${branch_type} - ${branch_hash} - ${branch} - TAG[${branch_tag}]"
      
      DPKG_BUILD_ROOT="${T_DIR}/.dpkg-root/${branch_hash}"
      mkdir -p "${DPKG_BUILD_ROOT}"

      ( 
         cd ${T_DIR}/* ; git checkout "${branch_hash}"
         if [ -r ".include.build.deb.sh" ]   
         then
            echo "- sourcing build..."
            source ".include.build.deb.sh"
            find "${DPKG_BUILD_ROOT}"
         fi
      )

   done

)

