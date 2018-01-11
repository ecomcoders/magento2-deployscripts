#!/usr/bin/env bash
set -euo pipefail

MAGENTO_CLI='php -d memory_limit=512M bin/magento'
MAGENTO_ROOT=$(pwd -P)

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

prepare-db-rollback()
{
    echo "----------------------------------------------------"
    echo "START: Prepared DB rollback"
    if [ -n "$PREVIOUS_BUILDNUMBER" ]; then
        vendor/bin/ecomcoders-prepare-db-rollback.sh
    else
        echo "SKIPPED: Prepared DB rollback - no previous build number given"
    fi
}

import_database_from_production_snapshot_to_staging()
{
    $N98 db:drop --tables --force
    $N98 db:import ${ENVROOTDIR}/../production/snapshots/latest/db/*.sql
}

apply_settings_from_est_csv_file()
{
    php vendor/bin/apply.php $ENVIRONMENT vendor/bin/magento2-settings.csv --excludeGroups sass
}

make_magento_production_ready()
{
    STATIC_CONTENT_DEPLOY_PARAMS=$($EST STATIC_CONTENT_DEPLOY_PARAMS)

    $MAGENTO_CLI setup:upgrade
    $MAGENTO_CLI setup:di:compile
    $MAGENTO_CLI setup:static-content:deploy $STATIC_CONTENT_DEPLOY_PARAMS
    $MAGENTO_CLI deploy:mode:set --skip-compilation production
    $MAGENTO_CLI cache:enable
    $MAGENTO_CLI cache:flush
}

run_sass_styles_processing()
{
    if [[ "YES" == "$TRIGGER_SASS_STYLES_PROCESSING" ]]; then
        echo "----------------------------------------------------"
        echo "START: SASS styles processing."
        cd vendor/snowdog/frontools
        npm install
        gulp setup
        cd $MAGENTO_ROOT
        php vendor/bin/apply.php $ENVIRONMENT vendor/bin/magento2-settings.csv --groups sass
        cd tools
        gulp styles
    else
        echo "----------------------------------------------------"
        echo "SKIPPED: SASS styles processing."
    fi
}

#######################################
# Main programm

make_bin_magento_executable
configure_magento2_environment
add_required_install_date

case $ENVIRONMENT in
    'production')
        prepare-db-rollback;;
    'staging')
        import_database_from_production_snapshot_to_staging;;
esac

apply_settings_from_est_csv_file
make_magento_production_ready
run_sass_styles_processing
