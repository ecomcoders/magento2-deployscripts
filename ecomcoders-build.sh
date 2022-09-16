#!/usr/bin/env bash
set -euo pipefail

BUILD_NUMBER=''
PACKAGE_PATH='../../artifacts/'

usage="\


Commands:
  build.sh <options>
---------------------------------------
  -b                       build number
"

check_if_build_number_is_given()
{
    if [ -z ${BUILD_NUMBER} ]; then
        echo "ERROR: No build number given (-b)"
        exit 1
    fi
}

create_package()
{
    if [ ! -d "$PACKAGE_PATH" ] ; then mkdir "$PACKAGE_PATH" ; fi

    PACKAGE_NAME="build-${BUILD_NUMBER}.tgz"

    echo "Creating package '${PACKAGE_NAME}'"
    echo "----------------------------------------------------"
    tar -czf "${PACKAGE_PATH}${PACKAGE_NAME}" \
        --exclude='.git' \
        --exclude='.github/' \
        --exclude=dev/ \
        --exclude=**/update/** \
        --exclude=**/Test/** \
        --exclude='.*auth\.json' .
}
#######################################
# Main programm
while getopts 'b:' OPTION ; do
case "${OPTION}" in
        b)BUILD_NUMBER="${OPTARG}";;
        \?) echo "$usage";;
        :) echo "Option -$OPTARG requires an argument."; exit 1;;
    esac
done

check_if_build_number_is_given
create_package
