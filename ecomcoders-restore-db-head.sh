#!/usr/bin/env bash

set -euo pipefail

PATH_ENVIRONMENT=$(pwd -P)
PHP_BIN=$(which php)
DRY_RUN='YES'

get_db_credentials()
{
    cd current
    DB_HOST=$($N98 db:info host)
    DB_PASSWORD=$($N98 db:info password)
    DB_USER=$($N98 db:info username)
    DB_NAME_CURRENT=$($N98 db:info dbname)
    DB_NAME_HEAD=$($PHP_BIN vendor/bin/value.php production vendor/bin/magento2-settings.csv Est_Handler_SetVar DB_NAME)
    echo "----------------------------------------------------"
    echo "DB name (current): ${DB_NAME_CURRENT}"
    echo "DB name (head): ${DB_NAME_HEAD}"
}

check_rollback_mode()
{
    echo "----------------------------------------------------"
    if [[ "$DB_NAME_CURRENT" == "$DB_NAME_HEAD" ]]; then
        echo "ERROR: Current and head db names are identical. System not in rollback mode!!!"
        exit 1
    else
        echo "DONE: Check for rollback mode: OK!"
    fi
}

generate_tmp_file()
{
    TMPFILE=$(mktemp)
    trap cleanup EXIT
    echo "----------------------------------------------------"
    echo "DONE: Generate tmp file '${TMPFILE}'"
}

cleanup()
{
    rm "${TMPFILE}"
    echo "----------------------------------------------------"
    echo "DONE: Removing temp file '${TMPFILE}'"
}

set_maintenance_flag()
{
    if [[ "NO" == "$DRY_RUN" ]]; then
        echo "----------------------------------------------------"
        $PHP_BIN bin/magento maintenance:enable
    fi
}

backup_current_database()
{
    echo "----------------------------------------------------"
    echo "START: Backup current DB '${DB_NAME_CURRENT}' to '${TMPFILE}'"
    mysqldump -u${DB_USER} -p${DB_PASSWORD} -h${DB_HOST} ${DB_NAME_CURRENT} > ${TMPFILE}
    echo "----------------------------------------------------"
    echo "DONE: Backup current DB"
}

check_db_backup()
{
    echo "----------------------------------------------------"
    if [ -s "$TMPFILE" ]; then
        echo "DONE: DB-Backup is ok. Filesize is $(wc -c < ${TMPFILE}) bytes"
    else
        echo "ERROR: DB-Backup file is empty!!!"
        exit 1
    fi
}

drop_tables_from_db_head()
{
    TABLES=$(mysql -u${DB_USER} -p${DB_PASSWORD} -h${DB_HOST} ${DB_NAME_HEAD} -e "SHOW TABLES" | awk '{print $1}' | grep -v '^Tables' || true)

    if [[ -n "$TABLES" ]]; then
        for TABLE in $TABLES; do
            if [[ "NO" == "$DRY_RUN" ]]; then
                mysql -u${DB_USER} -p${DB_PASSWORD} -h${DB_HOST} ${DB_NAME_HEAD} -e "SET FOREIGN_KEY_CHECKS = 0; DROP TABLE ${TABLE}; SET FOREIGN_KEY_CHECKS = 1;"
                echo "DONE: Dropped table ${TABLE}"
            else
                echo "SKIPPED (DRY RUN): Dropped table ${TABLE}"
            fi
        done
        echo "----------------------------------------------------"
        echo "DONE: Dropped all tables in database ${DB_NAME_HEAD}"
    else
        echo "----------------------------------------------------"
        echo "ERROR: No Tables found. DB-Head cannot be empty!!!"
        exit 1
    fi
}

import_db_backup()
{
    echo "----------------------------------------------------"
    if [[ "NO" == "$DRY_RUN" ]]; then
        echo "START: Restore db head: ${DB_NAME_HEAD}"
        mysql -u${DB_USER} -p${DB_PASSWORD} -h${DB_HOST} ${DB_NAME_HEAD} < ${TMPFILE}
        echo "DONE: Restore db head: ${DB_NAME_HEAD}"
    else
        echo "SKIPPED (DRY RUN): Restore db head: ${DB_NAME_HEAD}"
    fi
}

change_db_name_in_env_file()
{
    if [[ "NO" == "$DRY_RUN" ]]; then
        $PHP_BIN bin/magento setup:config:set --db-name=${DB_NAME_HEAD}
        echo "----------------------------------------------------"
        echo "DONE: Modified db name in env.php"
    else
        echo "----------------------------------------------------"
        echo "SKIPPED: Modified db name in env.php"
    fi

    cat app/etc/env.php
}

clear_cache()
{
    if [[ "NO" == "$DRY_RUN" ]]; then
        $PHP_BIN bin/magento cache:flush
    fi
}

remove_maintenance_flag()
{
    if [[ "NO" == "$DRY_RUN" ]]; then
        echo "----------------------------------------------------"
        $PHP_BIN bin/magento maintenance:disable
    fi
}
#######################################
# Main programm
while getopts 'd:p:' OPTION; do
    case "${OPTION}" in
        d)
            DRY_RUN="${OPTARG}"
            ;;
        p)
            PHP_BIN="${OPTARG}"
            ;;
    esac
done

N98="$PHP_BIN vendor/bin/n98-magerun2"

get_db_credentials
check_rollback_mode
generate_tmp_file
set_maintenance_flag
backup_current_database
check_db_backup
drop_tables_from_db_head
import_db_backup
change_db_name_in_env_file
clear_cache
remove_maintenance_flag