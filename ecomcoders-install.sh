#!/usr/bin/env bash
set -euo pipefail

MAGENTO_CLI="$PHP_BIN -d memory_limit=512M bin/magento"
MAGENTO_ROOT=$(pwd -P)

make_bin_magento_executable()
{
    chmod u+x bin/magento
}

configure_magento2_environment()
{
    $MAGENTO_CLI setup:config:set \
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
  ,\n"install" => ["date" => "Wed,\ 28\ Jun\ 2017\ 13:59:53\ +0000"]
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

add_cache_hosts()
{
    if [[ "YES" == "$ADD_CACHE_HOSTS" ]]; then
        HTTP_CACHE_HOSTS=$($EST HTTP_CACHE_HOSTS)
        echo "----------------------------------------------------"
        echo "START: Add http cache hosts: $HTTP_CACHE_HOSTS"
        $MAGENTO_CLI setup:config:set --http-cache-hosts=$HTTP_CACHE_HOSTS
    else
        echo "----------------------------------------------------"
        echo "SKIPPED: Add http cache hosts."
    fi
}

make_magento_production_ready()
{
    STATIC_CONTENT_DEPLOY_PARAMS=$($EST STATIC_CONTENT_DEPLOY_PARAMS)

    $MAGENTO_CLI setup:upgrade
    $MAGENTO_CLI setup:di:compile
    $MAGENTO_CLI deploy:mode:set --skip-compilation production
    $MAGENTO_CLI setup:static-content:deploy $STATIC_CONTENT_DEPLOY_PARAMS
    $MAGENTO_CLI cache:enable
    $MAGENTO_CLI cache:flush
}

run_sass_styles_processing()
{
    if [[ "YES" == "$TRIGGER_SASS_STYLES_PROCESSING" ]]; then
        echo "----------------------------------------------------"
        echo "START: SASS styles processing."
        cd vendor/snowdog/frontools
        npm set progress=false
        npm install
        gulp setup
        cd $MAGENTO_ROOT
        $PHP_BIN vendor/bin/apply.php $ENVIRONMENT vendor/bin/magento2-settings.csv --groups sass-step-1
        cd tools

        # Disable source maps generation in production environment
        if [[ "$ENVIRONMENT" == production ]]; then
            echo "SASS: Disable maps while in production environment"
            gulp styles --disableMaps
        else
            gulp styles
        fi

        echo "START: Copy compiled css files back to theme vendor directory to enable proper merging/minification"
        echo "SEE: \Magento\Framework\View\Design\FileResolution\Fallback\Resolver\Simple::resolveFile()"
        cd $MAGENTO_ROOT
        $PHP_BIN vendor/bin/apply.php $ENVIRONMENT vendor/bin/magento2-settings.csv --groups sass-step-2
    else
        echo "----------------------------------------------------"
        echo "SKIPPED: SASS styles processing."
    fi
}

flush_varnish()
{
    if [[ "YES" == "$ADD_CACHE_HOSTS" ]]; then
        curl -X BAN $($EST PROJECT_DOMAIN)
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
add_cache_hosts
make_magento_production_ready
run_sass_styles_processing
flush_varnish