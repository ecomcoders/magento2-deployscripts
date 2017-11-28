#!/usr/bin/env bash
set -euo pipefail

MYSQL_BIN=$(which mysql)
MYSQLDUMP_BIN=$(which mysqldump)
PHP_BIN=$(which php)
RSYNC_BIN=$(which rsync)
DATE=$(date +%d-%m-%Y_%H-%M)
PATH_SCRIPT=$(pwd)/$(dirname "$0")
PATH_MEDIA="${PATH_SCRIPT}/../../pub/media"
PATH_DB_TEMP=${PATH_SCRIPT}../../../../'sync-manager-tmp'
PATH_DB_TEMP_BACKUP=${PATH_DB_TEMP}/backup
PATH_DB_TEMP_IMPORT=${PATH_DB_TEMP}/import

. $PATH_SCRIPT/../../../../sync-manager-config.sh


usage="\
Sync Manager

Commands:
  sync-manager [<options>] <command>
---------------------------------------
  all                      sync modules (see below), media and database with remote snapshot
  modules                  get latest versions by composer, re-create symlinks and apply environment settings
  media                    sync media with remote snapshot
  db                       sync databse with remote snapshot
  --help                   show manual
"

sync_media()
{
    $RSYNC_BIN -rz -e "ssh -p $SSH_PORT" --size-only --itemize-changes --exclude='cache/' --exclude='css/' --exclude='js/' --exclude='.thumbs' $SSH_HOST:${REMOTE_BACKUP_PATH}/media/ $PATH_MEDIA
    echo "----------------------------------------------------"
    echo "DONE: Sync media from remote path: ${REMOTE_BACKUP_PATH}"
}

#######################################
# Main programm
options=${*:-}
set -- "$options"

case $1 in
    'media')
        sync_media;;
    *)
        echo "$usage";;
esac