#!/bin/bash

DESTINATION_FOLDER="${DESTINATION_ROOT}/${BACKUP_NAME}"
TS=`date +%Y%m%d_%H%M%S`

FULL_BASE_FOLDER="${DESTINATION_FOLDER}/full"
FULL_TARGET_FOLDER="${FULL_BASE_FOLDER}/${TS}"
FULL_TEMP_FOLDER="${FULL_BASE_FOLDER}/temp/${TS}"

INCREMENTAL_BASE_FOLDER="${DESTINATION_FOLDER}/incremental"
INCREMENTAL_TARGET_FOLDER="${INCREMENTAL_BASE_FOLDER}/${TS}"
INCREMENTAL_TEMP_FOLDER="${INCREMENTAL_BASE_FOLDER}/temp/${TS}"


# Check last command success
# $1 - error message to show when error occurs
function ensure_success() {
    if [ $? != 0 ]; then
        >&2 echo $1
        exit 1
    fi
}


# Remove old backups
# $1 - the remote directory that contains backups
# $2 - the maximum backups to keep
function prune_backups() {
ssh root@${DESTINATION_HOST} << EOF
    set -e
    if [ ! -e $1 ]; then
        exit 0
    fi
    cd $1
    backup_cnt=\`ls -d ????????_?????? | wc -l\`
    remain=\$((\$backup_cnt - $2))
    if [ \$remain -gt 0 ]; then
        ls -d ????????_?????? | sort | head -\$remain | xargs rm -rf
    fi
EOF
    ensure_success "failed to remove old backups"
}

# create an full backup
# No parameter
function full_backup() {
    prune_backups ${FULL_BASE_FOLDER} ${MAX_FULL_BACKUP}

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

# create an incremental backup
# if there's no last backup, do a full backup first
function incremental_backup() {
    prune_backups ${INCREMENTAL_BASE_FOLDER} ${MAX_INCREMENTAL}

ssh root@${DESTINATION_HOST} << EOF
    set -e
    mkdir -p ${INCREMENTAL_BASE_FOLDER}
    cd ${INCREMENTAL_BASE_FOLDER}
    if ls -d ????????_?????? > /dev/null 2>&1; then
        cp -al \`ls -d ????????_?????? | sort | tail -1\` ${INCREMENTAL_TEMP_FOLDER}
    else
        mkdir -p ${INCREMENTAL_TEMP_FOLDER}
    fi
EOF
    ensure_success "failed to setup remote hard link"

    rsync -av --delete ${BACKUP_DIRECTORY} root@${DESTINATION_HOST}:${INCREMENTAL_TEMP_FOLDER}
    ensure_success "failed to run rsync"

ssh root@${DESTINATION_HOST} << EOF
    mv ${INCREMENTAL_TEMP_FOLDER} ${INCREMENTAL_TARGET_FOLDER}
EOF
    ensure_success "failed to mv fold from ${INCREMENTAL_TEMP_FOLDER} to ${INCREMENTAL_TARGET_FOLDER}"
}

if [ "$1" == "full" ]; then
    time full_backup
elif [ "$1" == "incremental" ]; then
    time incremental_backup
else
    echo "should specify either full or incremental"
fi
