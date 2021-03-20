#!/usr/bin/env bash
set -euo pipefail

create_backup()
{
    RESULT=$(aws backup start-backup-job --backup-vault-name Default --resource-arn $RESOURCE_ARN --lifecycle DeleteAfterDays=7 --iam-role-arn $IAM_ROLE_ARN)
    echo "BACKUP TRIGGERED: $RESULT"
}

install_updates()
{
    echo -n "Install OS Updates? (Y/n): "
    read INSTALL_UPDATES

    if [[ "$INSTALL_UPDATES" == "Y" ]]; then
        sudo apt-get -qq update
        sudo apt-get autoremove
        sudo apt upgrade
        sudo apt-get clean
    else
        echo "SKIPPED: Install OS Updates"
    fi
}

check_reboot()
{
    if [ -f /var/run/reboot-required ]; then
        echo "----------------------------------------------------"
        cat /var/run/reboot-required
        echo "SYSTEM MUST BE REBOOTED!!! REBOOT NOW? (Y/n): "
        read DO_REBOOT

        if [[ "$DO_REBOOT" == "Y" ]]; then
            sudo reboot
        else
            echo "SKIPPED: System reboot"
        fi
    else
        echo "----------------------------------------------------"
        echo "NO REBOOT REQUIRED AT THIS TIME"
        echo "----------------------------------------------------"
    fi
}

function processArgs()
{
    # Parse Arguments
    for arg in "$@"
    do
        case $arg in
            --resource-arn=*)
                RESOURCE_ARN="${arg#*=}"
            ;;
            --iam-role-arn=*)
                IAM_ROLE_ARN="${arg#*=}"
            ;;
        esac
    done
}

#######################################
# Main programm
processArgs
create_backup
install_updates
check_reboot

