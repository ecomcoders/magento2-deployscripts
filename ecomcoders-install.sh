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

add_required_install_date()
{
    sed -i -e '$ i\
  'install' => array ('date' => 'Wed,\ 28\ Jun\ 2017\ 13:59:53\ +0000',)
' app/etc/env.php
}

#######################################
# Main programm

# @TODO set BaseURLs
# @TODO set production mode
# @TODO activate caches
# @TODO enable modules

make_bin_magento_executable
configure_magento2_environment
add_required_install_date
