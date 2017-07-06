#!/usr/bin/env bash
set -exuo pipefail

MAGENTO_CLI='php -d memory_limit=512M bin/magento'

make_bin_magento_executable()
{
    chmod u+x bin/magento
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
  "install" => array ("date" => "Wed,\ 28\ Jun\ 2017\ 13:59:53\ +0000",)
' app/etc/env.php

    sed -i -e "s/\"/'/g" app/etc/env.php
}

make_magento_production_ready()
{
    $MAGENTO_CLI setup:upgrade
    $MAGENTO_CLI setup:static-content:deploy
    $MAGENTO_CLI setup:di:compile
    $MAGENTO_CLI deploy:mode:set --skip-compilation production
    $MAGENTO_CLI cache:enable
    $MAGENTO_CLI cache:flush

    echo "----------------------------------------------------"
    echo "CURRENT APP STATUS"
    echo "----------------------------------------------------"
    $MAGENTO_CLI setup:db:status
    $MAGENTO_CLI deploy:mode:show
    $MAGENTO_CLI cache:status
}
#######################################
# Main programm

# @TODO set BaseURLs

make_bin_magento_executable
configure_magento2_environment
add_required_install_date
make_magento_production_ready
