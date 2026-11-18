#!/bin/bash
# ==============================================================================
# Script: restore.sh
# Description: Automated Cloud Backup Restoration & Verification Script
# Usage: ./restore.sh <S3_ARCHIVE_PATH_OR_NAME>
# ==============================================================================

set -euo pipefail

RESTORE_DIR="/var/data/restored"
RESTORE_STAGING="/tmp/restore_staging"
S3_BUCKET="cloud-backup-vault-9k6tfc"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <s3-backup-key-or-filename>"
    echo "Example: $0 backups/2026-11-18/backup_2026-11-18_155000.tar.gz"
    exit 1
fi

BACKUP_TARGET="$1"

# If user provided just filename, search S3
if [[ "${BACKUP_TARGET}" != s3://* && "${BACKUP_TARGET}" != backups/* ]]; then
    FULL_S3_PATH=$(aws s3 ls "s3://${S3_BUCKET}/backups/" --recursive | grep "${BACKUP_TARGET}" | tail -n 1 | awk '{print $4}')
    if [ -z "${FULL_S3_PATH}" ]; then
        echo "[ERROR] Could not find ${BACKUP_TARGET} in s3://${S3_BUCKET}/backups/"
        exit 2
    fi
    S3_URI="s3://${S3_BUCKET}/${FULL_S3_PATH}"
elif [[ "${BACKUP_TARGET}" == s3://* ]]; then
    S3_URI="${BACKUP_TARGET}"
else
    S3_URI="s3://${S3_BUCKET}/${BACKUP_TARGET}"
fi

ARCHIVE_FILENAME=$(basename "${S3_URI}")
mkdir -p "${RESTORE_STAGING}" "${RESTORE_DIR}"

echo "[INFO] === STARTING RESTORATION PROCEDURE ==="
echo "[INFO] Source S3 Archive: ${S3_URI}"
echo "[INFO] Destination Path : ${RESTORE_DIR}"

# 1. Download Archive and Checksum
echo "[INFO] Downloading backup archive..."
aws s3 cp "${S3_URI}" "${RESTORE_STAGING}/${ARCHIVE_FILENAME}"

echo "[INFO] Downloading checksum..."
aws s3 cp "${S3_URI}.sha256" "${RESTORE_STAGING}/${ARCHIVE_FILENAME}.sha256"

# 2. Checksum Verification
echo "[INFO] Verifying SHA-256 checksum..."
cd "${RESTORE_STAGING}"
if sha256sum --check "${ARCHIVE_FILENAME}.sha256"; then
    echo "[SUCCESS] Checksum verification PASSED!"
else
    echo "[ERROR] Checksum verification FAILED! Backup is corrupted."
    exit 3
fi

# 3. Extract Files
echo "[INFO] Extracting files into ${RESTORE_DIR}..."
tar -xzvf "${RESTORE_STAGING}/${ARCHIVE_FILENAME}" -C "${RESTORE_DIR}"

echo "[INFO] Verifying extracted files:"
ls -la "${RESTORE_DIR}"

rm -rf "${RESTORE_STAGING}"
echo "[SUCCESS] === RESTORATION COMPLETED SUCCESSFULLY ==="
