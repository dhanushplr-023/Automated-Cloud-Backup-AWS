#!/bin/bash
# ==============================================================================
# Script: backup.sh
# Description: Automated Cloud Backup & Integrity Verification Script
# Target: Compresses source directory, verifies checksum, and uploads to S3
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------
SOURCE_DIR="/var/data/important"
BACKUP_DIR="/tmp/backup_staging"
LOG_DIR="/opt/backup/logs"
S3_BUCKET="cloud-backup-vault-9k6tfc"

TIMESTAMP=$(date +"%Y-%m-%d_%H%M%S")
DATE_PREFIX=$(date +"%Y-%m-%d")
ARCHIVE_NAME="backup_${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="${BACKUP_DIR}/${ARCHIVE_NAME}"
CHECKSUM_FILE="${ARCHIVE_PATH}.sha256"
LOG_FILE="${LOG_DIR}/backup_${DATE_PREFIX}.log"

# ------------------------------------------------------------------------------
# SETUP LOGGING & DIRECTORIES
# ------------------------------------------------------------------------------
mkdir -p "${BACKUP_DIR}" "${LOG_DIR}"

log() {
    local level="$1"
    local message="$2"
    local log_entry="[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] ${message}"
    echo "${log_entry}"
    echo "${log_entry}" >> "${LOG_FILE}"
}

cleanup() {
    log "INFO" "Cleaning up temporary staging files..."
    rm -rf "${BACKUP_DIR}"
}
trap cleanup EXIT

# ------------------------------------------------------------------------------
# PRE-FLIGHT CHECKS
# ------------------------------------------------------------------------------
log "INFO" "=== STARTING AUTOMATED BACKUP PROCEDURE ==="
log "INFO" "Source Directory : ${SOURCE_DIR}"
log "INFO" "Target S3 Bucket : s3://${S3_BUCKET}/backups/${DATE_PREFIX}/"

if [ ! -d "${SOURCE_DIR}" ]; then
    log "ERROR" "Source directory ${SOURCE_DIR} does not exist!"
    exit 1
fi

if [ -z "$(ls -A "${SOURCE_DIR}")" ]; then
    log "WARNING" "Source directory ${SOURCE_DIR} is empty. Proceeding anyway."
fi

# ------------------------------------------------------------------------------
# 1. CREATE COMPRESSED ARCHIVE (tar + gzip)
# ------------------------------------------------------------------------------
log "INFO" "Creating compressed archive: ${ARCHIVE_NAME}..."
tar -czf "${ARCHIVE_PATH}" -C "${SOURCE_DIR}" .

ARCHIVE_SIZE=$(du -h "${ARCHIVE_PATH}" | cut -f1)
log "INFO" "Archive created successfully. Size: ${ARCHIVE_SIZE}"

# ------------------------------------------------------------------------------
# 2. INTEGRITY VERIFICATION (Checksum & Tar Table of Contents)
# ------------------------------------------------------------------------------
log "INFO" "Performing integrity test on archive..."
if ! tar -tzf "${ARCHIVE_PATH}" > /dev/null 2>&1; then
    log "ERROR" "Archive corruption detected! tar table of contents test failed."
    exit 2
fi
log "INFO" "Archive structure verified. Generating SHA-256 checksum..."

sha256sum "${ARCHIVE_PATH}" > "${CHECKSUM_FILE}"
CHECKSUM_VAL=$(awk '{print $1}' "${CHECKSUM_FILE}")
log "INFO" "SHA-256: ${CHECKSUM_VAL}"

# ------------------------------------------------------------------------------
# 3. UPLOAD ARCHIVE & CHECKSUM TO S3
# ------------------------------------------------------------------------------
S3_DESTINATION="s3://${S3_BUCKET}/backups/${DATE_PREFIX}/${ARCHIVE_NAME}"
S3_CHECKSUM_DEST="s3://${S3_BUCKET}/backups/${DATE_PREFIX}/${ARCHIVE_NAME}.sha256"

log "INFO" "Uploading archive to Amazon S3: ${S3_DESTINATION}..."
aws s3 cp "${ARCHIVE_PATH}" "${S3_DESTINATION}"

log "INFO" "Uploading checksum to Amazon S3: ${S3_CHECKSUM_DEST}..."
aws s3 cp "${CHECKSUM_FILE}" "${S3_CHECKSUM_DEST}"

# ------------------------------------------------------------------------------
# 4. VERIFY REMOTE OBJECT IN S3
# ------------------------------------------------------------------------------
log "INFO" "Verifying object existence in S3..."
if aws s3 ls "${S3_DESTINATION}" > /dev/null 2>&1; then
    log "SUCCESS" "Backup archive confirmed in Amazon S3!"
else
    log "ERROR" "Backup uploaded but could not be verified in S3!"
    exit 3
fi

log "SUCCESS" "=== BACKUP COMPLETED SUCCESSFULLY ==="
exit 0
