#!/usr/bin/env bash
set -exuo pipefail

MAGENTO_CLI='php -d memory_limit=512M bin/magento'

make_bin_magento_executable()
{
    chmod +x bin/magento
}

configure_magento2_environment()
{
    bin/magento setup:config:set \
        --backend-frontname=$($EST BACKEND_FRONTNAME) \
        --key=$($EST KEY) \
        --db-host=$($EST DB_HOST) \
        --db-name=$($EST DB_NAME) \
        --db-user=$($EST DB_USERNAME) \
        --db-password=$($EST DB_PASSWORD)
}

#######################################
# Main programm

# @TODO set BaseURLs
# @TODO set production mode
# @TODO activate caches
# @TODO enable modules

make_bin_magento_executable
configure_magento2_environment
