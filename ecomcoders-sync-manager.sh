#!/usr/bin/env bash
set -euo pipefail

MYSQL_BIN=$(which mysql)
MYSQLDUMP_BIN=$(which mysqldump)
PHP_BIN=$(which php)
RSYNC_BIN=$(which rsync)
DATE=$(date +%d-%m-%Y_%H-%M)
PATH_SCRIPT=$(pwd)/$(dirname "$0")
PATH_MEDIA="${PATH_SCRIPT}/../../pub/media"
PATH_DB_TEMP=${PATH_SCRIPT}/../../../../sync-manager/tmp
PATH_DB_TEMP_BACKUP=${PATH_DB_TEMP}/backup
PATH_DB_TEMP_IMPORT=${PATH_DB_TEMP}/import
PATH_PROJECT_ROOT=${PATH_SCRIPT}/../../../../
N98="${PATH_SCRIPT}/n98-magerun2"
M2_CLI="${PATH_SCRIPT}/../../bin/magento"
DB_NAME=$($N98 db:info dbname)
DB_HOST=$($N98 db:info host)
DB_USER=$($N98 db:info username)
DB_PASSWORD=$($N98 db:info password)

. ${PATH_PROJECT_ROOT}sync-manager/config.sh
. ${PATH_PROJECT_ROOT}.env


usage="\
Sync Manager

Commands:
  sync-manager [<options>] <command>
---------------------------------------
  media                    sync media with remote snapshot
  db                       sync databse with remote snapshot
  --help                   show manual
"

sync_media()
{
    $RSYNC_BIN -rz -e "ssh -p $SSH_PORT" --size-only --delete --itemize-changes --exclude='cache/' --exclude='tmp/' --exclude='.thumbs' $SSH_HOST:${REMOTE_BACKUP_PATH}/media/ $PATH_MEDIA
    echo "----------------------------------------------------"
    echo "DONE: Sync media from remote path: ${REMOTE_BACKUP_PATH}"
}

check_and_create_tmp_directory()
{
    if [ ! -d "$PATH_DB_TEMP_BACKUP" ]; then
        mkdir -p "$PATH_DB_TEMP_BACKUP"
    fi

    if [ ! -d "$PATH_DB_TEMP_IMPORT" ]; then
        mkdir -p "$PATH_DB_TEMP_IMPORT"
    fi
}

copy_database_from_remote()
{
    echo "----------------------------------------------------"
    echo "START: Copy database from production latest backup to local sync manager temporary directory"
    $RSYNC_BIN -zP -e "ssh -p $SSH_PORT" $SSH_HOST:${REMOTE_BACKUP_PATH}/db/*.sql $PATH_DB_TEMP_IMPORT
}

backup_local_db()
{
    echo "----------------------------------------------------"
    echo "START: Backup local database: ${DB_NAME}"
    mysqldump -u${DB_USER} -p${DB_PASSWORD} -h${DB_HOST} ${DB_NAME} > ${PATH_DB_TEMP_BACKUP}/${DB_NAME}.sql
}

import_database()
{
    cd $PATH_DB_TEMP_IMPORT
    PRD_DB_NAME=(*.sql)
    echo "----------------------------------------------------"
    echo "START: Import production database ${PRD_DB_NAME}"
    $MYSQL_BIN -u${DB_USER} -p${DB_PASSWORD} -h${DB_HOST} ${DB_NAME} -e 'SET GLOBAL max_allowed_packet=104857600'
    $MYSQL_BIN -u${DB_USER} -p${DB_PASSWORD} -h${DB_HOST} ${DB_NAME} < *.sql
}

change_base_urls_to_dev()
{
    cd $PATH_SCRIPT
    $N98 config:set web/unsecure/base_url $BASE_URL
    $N98 config:set web/secure/base_url $BASE_URL
}

create_admin_user()
{
    $N98 admin:user:create \
        --admin-user $ADMIN_USERNAME \
        --admin-password $ADMIN_PASSWORD \
        --admin-email $ADMIN_EMAIL \
        --admin-firstname $ADMIN_FIRSTNAME \
        --admin-lastname $ADMIN_LASTNAME
    echo "----------------------------------------------------"
    echo "DONE: Create admin user with username '${ADMIN_USERNAME}' and password '${ADMIN_PASSWORD}'"
}

upgrade_database()
{
    #we always have to upgrade database due to extension used/deployed in dev
    $M2_CLI setup:db-schema:upgrade
    $M2_CLI setup:db-data:upgrade
}

clear_cache()
{
    $M2_CLI cache:flush
}

#######################################
# Main programm
options=${*:-}
set -- "$options"

case $1 in
    'media')
        sync_media;;
    'db')
        check_and_create_tmp_directory
        copy_database_from_remote
        backup_local_db
        import_database
        change_base_urls_to_dev
        create_admin_user
        # execute_envsettigstool_exclude_groups
        upgrade_database
        clear_cache;;
    *)
        echo "$usage";;
esac