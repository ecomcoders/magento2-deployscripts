#!/usr/bin/env bash
set -exuo pipefail

EST="php vendor/bin/value.php $ENVIRONMENT vendor/bin/magento2-settings.csv Est_Handler_SetVar"


configure_magento2_environment()
{
    bin/magento setup:config:set \
        --backend-frontname=$($EST BACKEND_FRONTNAME) \
        --key=$($EST KEY) \
        --db-host=$($EST DB_HOST) \
        --db-name=$($EST DB_NAME) \
        --db-user=$($EST DB_USER) \
        --db-password=$($EST DB_PASSWORD)
}


#######################################
# Main programm

# @TODO symlink media and var folder!
# @TODO set BaseURLs

configure_magento2_environment