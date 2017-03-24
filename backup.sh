#!/bin/bash

##################################################################
# Backup Scripts
# This scripts make incremental or full backups of your folder
# To make a full backup: ./backup.sh full
# To make a incremental backup: ./backup.sh incremental
#
# Before run this script, below profile variables must be defined
# and export to this script:
# BACKUP_NAME - The unique name of this backup
# BACKUP_DIRECTORY - The directory you want to backup
# DESTINATION_HOST - The host where you want to save the backup
# DESTINATION_ROOT - The root directory of your backups on DESTINATION_HOST
# MAX_FULL_BACKUP - Max number of full backups to keep
# MAX_INCREMENTAL - Max number of incremental backups to keep
#
#
# Backup Folder Structure
#
# - DESTINATION_HOST:DESTINATION_ROOT
#  |- BACKUP_NAME
#  | |- full
#  | |  |- 20170101_120000
#  | |  |- 20170102_120000
#  | |  |- 20170102_120000
#  | |  |- temp
#  | |-incremental
#  | |  |- 20170101_120000
#  | |  |- temp
#  |- BACKUP_NAME
#  |- BACKUP_NAME
#
##################################################################

if [ -z ${BACKUP_NAME} ] || [ -z ${BACKUP_DIRECTORY} ] || [ -z ${DESTINATION_HOST} ] || [ -z ${DESTINATION_ROOT} ] || [ -z ${MAX_FULL_BACKUP} ] || [ -z ${MAX_INCREMENTAL} ]; then
    >&2 echo "profile variables not defned"
    exit 1
fi

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
    echo "Full backup from ${BACKUP_DIRECTORY} to ${DESTINATION_HOST}:${DESTINATION_FOLDER}"

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
    echo "Full backup from ${BACKUP_DIRECTORY} to ${DESTINATION_HOST}:${DESTINATION_FOLDER}"

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
