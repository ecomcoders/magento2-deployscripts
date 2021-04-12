#!/usr/bin/env bash

set -u

DRY_RUN='NO'

echo -e 'Subject: Image Optimization Report\n\n'

write_timestampfile()
{
    touch $LAST_SEEN_FILE
    echo "SUCCESS: Timestamp file written/updated"
    echo "----------------------------------------------------"
}

optimize_images()
{
    cd shared/pub/media

    if [[ ! -f "$LAST_SEEN_FILE" ]]; then
        # Timestamp file missing
        echo "----------------------------------------------------"
        echo "TIMESTAMP FILE DOES NOT EXIST!!! Filter for all JPG-Files instead."
        echo "----------------------------------------------------"


        if [[ "NO" == "$DRY_RUN" ]]; then
            # production
            echo 'Running in PRODUCTION mode'
            echo "----------------------------------------------------"
            find . -name '*.jpg' -not -wholename './catalog/product/*.jpg' | xargs jpegoptim -o -m70 --strip-all --all-progressive -t
            find . -wholename './catalog/product/cache/*.jpg' | xargs jpegoptim -o -m70 --strip-all --all-progressive -t
            write_timestampfile
        else
            # dry run
            echo 'DRY RUN'
            echo "----------------------------------------------------"
            find . -name '*.jpg' -not -wholename './catalog/product/*.jpg'
            find . -wholename './catalog/product/cache/*.jpg'
        fi
    else
        # Timestamp file found
        LAST_SEEN=$(date -r $LAST_SEEN_FILE)
        echo "----------------------------------------------------"
        echo "TIMESTAMP FILE FOUND!"
        echo "Filter for new JPG-Files since: $LAST_SEEN"
        echo "----------------------------------------------------"

        if [[ "NO" == "$DRY_RUN" ]]; then
            # production
            echo 'Running in PRODUCTION mode'
            echo "----------------------------------------------------"
            find . -newer $LAST_SEEN_FILE -name '*.jpg' -not -wholename './catalog/product/*.jpg' | xargs jpegoptim -o -m70 --strip-all --all-progressive -t
            find . -newer $LAST_SEEN_FILE -wholename './catalog/product/cache/*.jpg' | xargs jpegoptim -o -m70 --strip-all --all-progressive -t
            write_timestampfile
        else
            # dry run
            echo 'DRY RUN'
            echo "----------------------------------------------------"
            find . -newer $LAST_SEEN_FILE -name '*.jpg' -not -wholename './catalog/product/*.jpg'
            find . -newer $LAST_SEEN_FILE -wholename './catalog/product/cache/*.jpg'
        fi
    fi
}

#######################################
# Main programm
while getopts 'dp:' OPTION; do
    case "${OPTION}" in
        d)
            DRY_RUN="YES"
            ;;
        p)
            WORKING_DIRECTORY="${OPTARG}"
            ;;
    esac
done

cd $WORKING_DIRECTORY
PATH_ENVIRONMENT=$(pwd -P)
LAST_SEEN_FILE="${PATH_ENVIRONMENT}/shared/pub/image-optimization-last-run.txt"
optimize_images
