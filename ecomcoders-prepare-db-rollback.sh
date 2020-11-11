#!/usr/bin/env bash
set -euo pipefail

calculate_suffix()
{
    SUFFIX="${PREVIOUS_BUILDNUMBER: -1}"
    echo "----------------------------------------------------"
    echo "DONE: Calculate db name suffix: ${SUFFIX}"
}

generate_tmp_file()
{
    echo "----------------------------------------------------"
    echo "START: Generate tmp file ..."
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

get_db_credentials()
{
    echo "----------------------------------------------------"
    echo "START: Get db credentials"
    DB_HOST=$($N98 db:info host)
    DB_USER=$($N98 db:info username)
    DB_PASSWORD=$($N98 db:info password)
    SOURCE_DB_NAME=$($N98 db:info dbname)
    _TARGET_DB_NAME=$($EST DB_NAME_PREFIX)
    TARGET_DB_NAME="${_TARGET_DB_NAME}${SUFFIX}"

    echo "----------------------------------------------------"
    echo "DONE: Get db credentials. Target db name is: $TARGET_DB_NAME"
}

backup_production_db()
{
    echo "----------------------------------------------------"
    echo "START: Dump production database ..."
    mysqldump --no-tablespaces -u${DB_USER} -p${DB_PASSWORD} -h${DB_HOST} ${SOURCE_DB_NAME} > ${TMPFILE}
    echo "----------------------------------------------------"
    echo "DONE: Dump production database '${SOURCE_DB_NAME}' into ${TMPFILE}"
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

drop_tables()
{
    TABLES=$(mysql -u${DB_USER} -p${DB_PASSWORD} -h${DB_HOST} ${TARGET_DB_NAME} -e "SHOW TABLES" | awk '{print $1}' | grep -v '^Tables' || true)

    if [[ -n "$TABLES" ]]; then
        for TABLE in $TABLES; do
            mysql -u${DB_USER} -p${DB_PASSWORD} -h${DB_HOST} ${TARGET_DB_NAME} -e "SET FOREIGN_KEY_CHECKS = 0; DROP TABLE ${TABLE}; SET FOREIGN_KEY_CHECKS = 1;"
            echo "DONE: Dropped table ${TABLE}"
        done
        echo "----------------------------------------------------"
        echo "DONE: Dropped all tables in database ${TARGET_DB_NAME}"
    else
        echo "----------------------------------------------------"
        echo "SKIPPED: database '${TARGET_DB_NAME}' is empty. No tables dropped"
    fi
}

import_db_backup()
{
    echo "----------------------------------------------------"
    echo "Start: Import database backup from production into ${TARGET_DB_NAME}"
    mysql -u${DB_USER} -p${DB_PASSWORD} -h${DB_HOST} ${TARGET_DB_NAME} < ${TMPFILE}
    echo "----------------------------------------------------"
    echo "DONE: Import database backup."
}
#######################################
# Main programm
calculate_suffix
generate_tmp_file
get_db_credentials
backup_production_db
check_db_backup
drop_tables
import_db_backup
