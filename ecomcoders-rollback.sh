#!/usr/bin/env bash

set -euo pipefail

PATH_ENVIRONMENT=$(pwd -P)
N98='vendor/bin/n98-magerun2'
TARGET_DB_SUFFIX=''
CURRENT_DB_NAME=''
TARGET_DB_PREFIX=''
TARGET_DB_NAME=''

get_target_db_suffix()
{
    _TARGET_DB_SUFFIX=$(basename "$(readlink previous)")
    TARGET_DB_SUFFIX="${_TARGET_DB_SUFFIX: -1}"
    echo "----------------------------------------------------"
    echo "DONE: Get target db suffix '${TARGET_DB_SUFFIX}'"
}

get_current_db_name()
{
    cd -P current
    CURRENT_DB_NAME=$($N98 db:info dbname)
    echo "----------------------------------------------------"
    echo "DONE: Get current db name '${CURRENT_DB_NAME}'"
}

get_target_db_name()
{
    TARGET_DB_PREFIX=$(vendor/bin/value.php production tools-config/env-settings-tool/settings.csv Est_Handler_SetVar DB_NAME_PREFIX)
    TARGET_DB_NAME=${TARGET_DB_PREFIX}${TARGET_DB_SUFFIX}
    echo "----------------------------------------------------"
    echo "DONE: Get target db name '${TARGET_DB_NAME}'"
}

check_db_name_not_equal()
{
    if [[ "$TARGET_DB_NAME" == "$CURRENT_DB_NAME" ]]; then
        echo "----------------------------------------------------"
        echo "ERROR: Target and current db name are identical!!!"
        exit 1
    fi
}

change_db_name_in_env_file()
{
    echo "----------------------------------------------------"
    echo "START: Modify db name in env.php file"
    cd "${PATH_ENVIRONMENT}/previous"
    bin/magento setup:config:set --db-name=${TARGET_DB_NAME}
    echo "----------------------------------------------------"
    echo "DONE: Modified db name to ${TARGET_DB_NAME}"
}

clear_cache()
{
    bin/magento cache:flush
}

if [[ -L previous && -L current && -L latest && latest == $(readlink current) ]]; then
    get_target_db_suffix
    get_current_db_name
    get_target_db_name
    check_db_name_not_equal
    change_db_name_in_env_file
    clear_cache

    cd $PATH_ENVIRONMENT
    ln -sfn previous current
    echo "----------------------------------------------------"
    echo "DONE: Setting current symlink ('current') to 'previous'"

else
    echo "----------------------------------------------------"
    echo "ERROR: Already in rollback mode or no previous version available"
    exit 1
fi