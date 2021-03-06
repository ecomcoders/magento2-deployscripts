#!/usr/bin/env bash
set -euo pipefail

VALID_ENVIRONMENTS=" production staging "
BUILDFOLDER=''
PREVIOUS_BUILDFOLDER=''
export BUILDNUMBER=''
export PREVIOUS_BUILDNUMBER=''
export ENVROOTDIR=$(pwd -P)
export ENVIRONMENT=${ENVROOTDIR##*/}
export PHP_BIN=$(which php)
export TRIGGER_SASS_STYLES_PROCESSING='NO'
export ADD_CACHE_HOSTS='NO'


define_dynamic_variables()
{
    export EST="$PHP_BIN vendor/bin/value.php $ENVIRONMENT vendor/bin/magento2-settings.csv Est_Handler_SetVar"
    export N98="$PHP_BIN vendor/bin/n98-magerun2"
}

check_environment()
{
    echo "----------------------------------------------------"
    if [[ "${VALID_ENVIRONMENTS}" =~ " ${ENVIRONMENT} " ]] ; then
        echo "Environment: ${ENVIRONMENT}"
    else
        echo "ERROR: Illegal environment code" ; exit 1;
    fi
}

init_directory_structure()
{
    if [[ ! -d 'releases' && ! -d 'shared' && ! -L 'current' && ! -L 'latest' ]]; then
        echo "----------------------------------------------------"
        echo "Init directory structure"
        mkdir releases
        mkdir -p \
            shared/var/log \
            shared/var/report \
            shared/var/export \
            shared/sessions \
            shared/pub/media
        chmod g+w \
            shared/var/* \
            shared/sessions \
            shared/pub/media
    fi
}

get_build_number_and_release_folder()
{
    BUILDNUMBER=$(ls | grep build-*.tgz | sed -n "s/build-\(.*\).tgz/\1/p")
    echo "----------------------------------------------------"
    echo "BUILD: $BUILDNUMBER"

    BUILDFOLDER="build-${BUILDNUMBER}"
    echo "BUILDFOLDER: $BUILDFOLDER"
}

get_previous_buildnumber()
{
    if [[ -L current && -L latest && latest == $(readlink current) ]]; then
        PREVIOUS_BUILDFOLDER=$(readlink latest)
        PREVIOUS_BUILDNUMBER=${PREVIOUS_BUILDFOLDER##*/build-}
        echo "----------------------------------------------------"
        echo "Current build number is: $BUILDNUMBER"
        echo "Previous build number is: $PREVIOUS_BUILDNUMBER"
    else
        echo "----------------------------------------------------"
        echo 'Previous build number could not be determinate.'
        echo 'Either this is first build or instance is in rollback mode'
    fi
}

generate_tmp_dir()
{
    echo "----------------------------------------------------"
    echo "Generate tmp dir"
    TMPDIR=$(mktemp -d)
    trap cleanup EXIT
}

cleanup()
{
    echo "----------------------------------------------------"
    echo "Removing temp dir '${TMPDIR}'"
    rm -rf "${TMPDIR}"
}

extract_build_package()
{
    echo "----------------------------------------------------"
    echo "Extract package to temp dir"
    mkdir "${TMPDIR}/package"
    tar -xzvf build-*.tgz -C "${TMPDIR}/package"
}

move_files_to_release_folder()
{
    echo "----------------------------------------------------"
    echo "Move files to release folder"
    mv "${TMPDIR}/package" "releases/${BUILDFOLDER}"
}

copy_media_files_to_release_folder()
{
    case $ENVIRONMENT in
        'staging')
            copy_media_files_from_production_snapshot_to_staging;;
    esac
}

copy_media_files_from_production_snapshot_to_staging()
{
    echo "----------------------------------------------------"
    echo "Start syncing media files with production"
    rsync -a --size-only --delete --itemize-changes --exclude='cache/' --exclude='tmp/' --exclude='.thumbs' ../production/snapshots/latest/media/ shared/pub/media/
}

install_package()
{
    cd releases/${BUILDFOLDER}/
    wget --output-document=vendor/bin/n98-magerun2 https://files.magerun.net/n98-magerun2-3.2.0.phar
    chmod u+x vendor/bin/n98-magerun2
    shasum -a256 vendor/bin/n98-magerun2
    echo "SHA256 should be: 5b5b4f7a857f7716950b6ef090c005c455d5e607f800a50b7b7aefa86d1c4e36"
    vendor/bin/ecomcoders-install.sh
}
write_build_info_file()
{
    echo "----------------------------------------------------"
    echo "${BUILDNUMBER}" > pub/build.txt
}

update_filesystem_permissions()
{
    echo "----------------------------------------------------"
    echo "Update File System Permissions"
    chmod -Rf g+w pub/static || true
    chmod -Rf g+w var || true
}

generate_shared_directory_symlinks()
{
    echo "----------------------------------------------------"
    echo "Generate shared directory symlinks"
    cd var

    if [[ -d 'log' ]]; then
        rm -rf log
    fi

    if [[ -d 'report' ]]; then
        rm -rf report
    fi

    ln -sfn ../../../shared/var/log    log
    ln -sfn ../../../shared/var/report report
    ln -sfn ../../../shared/var/export export
    cd ..

    cd pub
    rm -rf media
    ln -sfn ../../../shared/pub/media  media
}

check_db_head()
{
    # Do not switch to a new build package when
    # current database in production is in detached head mode
    # (typically after rollback)
    cd $ENVROOTDIR
    if [[ "$ENVIRONMENT" == production && -L 'current' ]]; then
        echo "----------------------------------------------------"
        echo "Check db head"
        cd current
        CURRENT_DB_NAME=$($N98 db:info dbname)
        DB_NAME_HEAD=$($EST DB_NAME)

        if [[ "$DB_NAME_HEAD" != "$CURRENT_DB_NAME" ]]; then
            echo "----------------------------------------------------"
            echo "ERROR: Current db name '${CURRENT_DB_NAME}' is not set to db head '${DB_NAME_HEAD}'"
            exit 1
        fi
    fi
}

update_symlinks()
{
    cd $ENVROOTDIR
    echo "----------------------------------------------------"
    if [ -n "$PREVIOUS_BUILDNUMBER" ]; then
        ln -sfn $PREVIOUS_BUILDFOLDER previous
        echo "DONE: Setting previous symlink ('previous') to previous build folder: $(readlink latest)"
    else
        echo "SKIPPED: Setting previous symlink (System in rollback mode or is first build?)"
    fi

    ln -sfn "releases/${BUILDFOLDER}" latest
    echo "DONE: Setting latest symlink ('latest') to release folder (${ENVROOTDIR}/releases/${BUILDFOLDER})"

    ln -sfn latest current
    echo "DONE: Setting current symlink ('current') to 'latest'"
}

print_success_message()
{
    echo "----------------------------------------------------"
    echo "--> THIS PACKAGE IS LIVE NOW! <--"
}

remove_build_artifacts()
{
    echo "----------------------------------------------------"
    echo "Removed build artifacts"
    rm build-*.tgz
    rm ecomcoders-deploy.sh
}

cleanup_build_folder()
{
    cd releases/${BUILDFOLDER}
    vendor/bin/ecomcoders-deploy-cleanup.sh
}

#######################################
# Main programm
while getopts ':svp:' OPTION; do
    case "${OPTION}" in
        s)
            TRIGGER_SASS_STYLES_PROCESSING="YES"
            ;;
        v)
            ADD_CACHE_HOSTS="YES"
            ;;
        p)
            PHP_BIN="${OPTARG}"
            ;;
    esac
done

define_dynamic_variables
check_environment
init_directory_structure
get_build_number_and_release_folder
get_previous_buildnumber
generate_tmp_dir
extract_build_package
move_files_to_release_folder
copy_media_files_to_release_folder
install_package
write_build_info_file
update_filesystem_permissions
generate_shared_directory_symlinks
check_db_head
update_symlinks
print_success_message
remove_build_artifacts
cleanup_build_folder
