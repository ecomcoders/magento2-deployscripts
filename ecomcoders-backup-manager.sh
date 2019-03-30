#!/usr/bin/env bash
set -euo pipefail

DATE=$(date +%d-%m-%Y_%H-%M)
MAX_SNAPSHOTS_IN_ARCHIVE=4
INSTANCE_NAME=''
DB_HOST=''
DB_USER=''
DB_NAME=''
DB_PASSWORD=''
N98='php7.1 vendor/bin/n98-magerun2'

check_and_set_paths()
{
    path_script=$(cd -P "$(dirname "$0")" && pwd -P)
    path_build="${path_script}/../../"
    path_releases="${path_script}/../../../"
    path_environment="${path_script}/../../../../"
    path_snapshot_latest="${path_environment}snapshots/latest/"
    path_snapshot_archive="${path_environment}snapshots/archive/"
}

print_env_info()
{
    cd "${path_environment}../"
    INSTANCE_NAME=$(basename "$(pwd)")
    echo "----------------------------------------------------"
    echo "INSTANCE: $INSTANCE_NAME"
    echo "DATE: $DATE"
    echo "BACKUPS TO KEEP: $MAX_SNAPSHOTS_IN_ARCHIVE"
}

test_and_prepare_snashot_dir()
{
    cd $path_environment
    if [ ! -d 'snapshots' ]; then
        echo "----------------------------------------------------"
        echo "START: Create snapshot dir"
        mkdir -p snapshots/archive snapshots/latest
    fi
}

get_latest_build_name()
{
    echo "----------------------------------------------------"
    echo "START: Get latest build name ..."
    cd $path_build
    _pwd=$(pwd -P)
    latest_build_name=$(basename "$_pwd")
    echo "----------------------------------------------------"
    echo "END: Get latest build name: $latest_build_name"
}

archive_latest_backup()
{
    cd $path_snapshot_latest
    if [[ -d 'db' && -d 'media' && -d 'files' ]]; then
        echo "----------------------------------------------------"
        echo "START: Archive latest backup ..."
        build_name=$(ls | grep build-)
        rm -rf media/catalog/product/cache/*

        if [ -d 'media/catalog/__product' ]; then
            echo "----------------------------------------------------"
            echo "START: Found '__product' directory. Removing ..."
            rm -rf media/catalog/__product
        fi

        tar -czf "../archive/$DATE-$build_name.tgz" db files media build-*
        echo "----------------------------------------------------"
        echo "END: Archive latest backup: $DATE-$build_name.tgz"
    else
        echo "----------------------------------------------------"
        echo "END: Archive latest backup. No backup exists at this time!"
    fi
}

clean_up_archive()
{
    cd $path_snapshot_archive
    echo "----------------------------------------------------"
    echo "START: Delete old snaphots ..."
    snapshot_count=$(ls -1 | sed -n '/\.tgz/p' | wc -l | tr -d ' ')
    if (( $snapshot_count > $MAX_SNAPSHOTS_IN_ARCHIVE )); then
        old_snapshots=$(ls -t | sed -n '/\.tgz/p' | awk -v max=$MAX_SNAPSHOTS_IN_ARCHIVE 'NR > max' )
        rm -rf $old_snapshots
        echo "----------------------------------------------------"
        echo "END: Delete old snaphots: $old_snapshots"
    else
        echo "----------------------------------------------------"
        echo "END: Delete old snaphots. Nothing to delete!"
    fi
}

prepare_backup()
{
    cd $path_snapshot_latest

    if [[ -d 'db' && -d 'media' && -d 'files' ]]; then
        echo "----------------------------------------------------"
        echo "START: Delete old files in 'latest' directory"
        rm -rf db files media build-*
    fi

    mkdir db
    touch $latest_build_name
}

backup_files()
{
    echo "----------------------------------------------------"
    echo "START: Backup Code Files"
    cd $path_releases
    cp -a  $latest_build_name ${path_snapshot_latest}files
}

backup_media()
{
    echo "----------------------------------------------------"
    echo "START: Backup Media"
    cd $path_environment
    cp -a shared/pub/media ${path_snapshot_latest}media
}

backup_database()
{
    cd ${path_build}
    DB_NAME=$($N98 db:info dbname)
    DB_HOST=$($N98 db:info host)
    DB_USER=$($N98 db:info username)
    DB_PASSWORD=$($N98 db:info password)
    cd ${path_snapshot_latest}db

    echo "----------------------------------------------------"
    echo "START: Backup database: ${DB_NAME}"
    mysqldump -u${DB_USER} -p${DB_PASSWORD} -h${DB_HOST} ${DB_NAME} > db-${DB_NAME}.sql
}

print_summary()
{
    echo "----------------------------------------------------"
    echo "SUCCESS - DATE: $(date +%d-%m-%Y_%H-%M)"
}

#######################################
# Main programm
while getopts 'c:' OPTION; do
    case "${OPTION}" in
        c)MAX_SNAPSHOTS_IN_ARCHIVE="${OPTARG}";;
    esac
done

check_and_set_paths
print_env_info
test_and_prepare_snashot_dir
get_latest_build_name
prepare_backup
backup_files
backup_media
backup_database
archive_latest_backup
clean_up_archive
print_summary