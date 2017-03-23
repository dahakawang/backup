#!/bin/bash

DESTINATION_FOLDER="${DESTINATION_ROOT}/${BACKUP_NAME}"
TS=`date +%Y%m%d_%H%M%S`

FULL_TARGET_FOLDER="${DESTINATION_FOLDER}/${TS}"
FULL_TEMP_FOLDER="${DESTINATION_FOLDER}/temp/${TS}"


function ensure_success() {
    if [ $? != 0 ]; then
        >&2 echo $1
        exit 1
    fi
}

function full_backup() {
ssh root@${DESTINATION_HOST} << EOF
    mkdir -p ${FULL_TEMP_FOLDER}
EOF
    ensure_success "failed to create ${FULL_TEMP_FOLDER} on remote host ${DESTINATION_HOST}"

    rsync -av --delete ${BACKUP_DIRECTORY} root@${DESTINATION_HOST}:${FULL_TEMP_FOLDER}
    ensure_success "failed to run rsync"

ssh root@${DESTINATION_HOST} << EOF
    mv ${FULL_TEMP_FOLDER} ${FULL_TARGET_FOLDER}
EOF
    ensure_success "failed to mv fold from ${FULL_TEMP_FOLDER} to ${FULL_TARGET_FOLDER}"
}


if [ "$1" == "full" ]; then
    time full_backup
elif [ "$1" == "incremental" ]; then
    echo incremental
else
    echo "should specify either full or incremental"
fi
