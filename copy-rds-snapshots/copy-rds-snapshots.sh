#!/bin/bash
export PATH=$PATH:/usr/local/bin/:/usr/bin

# Safety feature: exit script if error is returned, or if variables not set.
# Exit if a pipeline results in an error.
set -ue
set -o pipefail

# initial variable declaration

# region in which your automated rds snapshots exist
source_region=${source_region:=eu-central-1}

# destination region of snapshots
destination_region=${destination_region:=eu-west-1}

# source arn of snapshots (must be definded, I did not find a way to extract that somehow from the snapshot description)
source_arn=${source_arn:-}

# list of Snapshot Identifiers of all automated snapshots in your regions
snapshot_list_source=$(aws rds describe-db-snapshots --region $source_region --snapshot-type automated --query DBSnapshots[].DBSnapshotIdentifier --output text)
snapshot_list_destination=$(aws rds describe-db-snapshots --region $destination_region --query DBSnapshots[].DBSnapshotIdentifier --output text)

# retention days
retention_days=${retention_days:=14}
retention_date_in_seconds=$(date +%s --date "$retention_days days ago")

#logging
logfile="/var/log/rds.log"
logfile_max_lines="5000"

# Function Declarations
#Function - test for needed variables

test_variables() {
  if [[ -z $AWS_ACCESS_KEY_ID || -z $AWS_SECRET_ACCESS_KEY || -z $source_region  || -z $destination_region || -z $source_arn  || -z $retention_days ]]; then
     echo "Please set AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY source_destination (default eu-central-1) destination_region (default eu-west-1) source_arn and retention_days (default 14) in env vars" 2>&1
     exit 1
  fi
}

# Function - check if logfile exists and is writeable
log_setup() {
    # Check if logfile exists and is writable.
    ( [ -e "$logfile" ] || touch "$logfile" ) && [ ! -w "$logfile" ] && echo "ERROR: Cannot write to $logfile. Check permissions or sudo access." && exit 1

    tmplog=$(tail -n $logfile_max_lines $logfile 2>/dev/null) && echo "${tmplog}" > $logfile
    exec > >(tee -a $logfile)
    exec 2>&1
}

# Function - log events
log() {
    echo "[$(date +"%Y-%m-%d"+"%T")]: $*"
}
# get a list of snapshots in source region
check_rds_snapshots() {
  for snapshot_id in $snapshot_list_source; do
        log "Snapshots in $source_region : $snapshot_id"
        snapshot_date=$(aws rds describe-db-snapshots --region $source_region --db-snapshot-identifier $snapshot_id --query DBSnapshots[].SnapshotCreateTime --output text | awk -F "T" '{printf "%s\n", $1}')
        snapshot_date_in_seconds=$(date --date "$snapshot_date" +%s)
        log "Time of Snapshot Creation $snapshot_date"
  done
}

# check if there is already a backup of the source snapshots in the destination region
check_for_rds_snapshots() {
   for snapshot_id in $snapshot_list_source; do
     log "Checking if Snapshot $snapshot_id already exists in $destination_region"
     identifier_source=$(aws rds describe-db-snapshots --region $source_region --db-snapshot-identifier $snapshot_id --query DBSnapshots[].DBSnapshotIdentifier --output text | awk -F ":" '{print $2}')
     log "snapshot identifier in FFM: $identifier_source"
     if aws rds describe-db-snapshots  --db-snapshot-identifier ${identifier_source}-backup-irl --region $destination_region --query DBSnapshots[].SourceDBSnapshotIdentifier --output text | awk -F "T" '{printf "%s\n", $1}'; then
          echo "snapshot $snapshot_id already exists in $destination_region"
       else
          echo "snapshot ${source_arn}:${snapshot_id} does not exists in $destination_region, initializing copy"
          aws rds copy-db-snapshot --source-db-snapshot-identifier ${source_arn}:${snapshot_id} --region $destination_region --target-db-snapshot-identifier ${identifier_source}-backup-irl
     fi
  done
}

#delete all snapshots older than retention age
cleanup_snapshots() {
  for snapshot_id in $snapshot_list_destination; do
    log "checking age of $snapshot_id"
    snapshot_date=$(aws rds describe-db-snapshots --region $destination_region --db-snapshot-identifier $snapshot_id --query DBSnapshots[].SnapshotCreateTime --output text | awk -F "T" '{printf "%s\n", $1}')
    snapshot_date_in_seconds=$(date --date "$snapshot_date" +%s)

    if (( $snapshot_date_in_seconds <= $retention_date_in_seconds)); then
          log "DELETING snapshot $snapshot_id which is older than retention time"
          aws rds delete-db-snapshot --db-snapshot-identifier $snapshot_id --region $destination_region
    else
         log "Not deleting snapshot $snapshot_id in $destination_region"
    fi
  done
}


log_setup
test_variables
#get_rds_snapshots
check_for_rds_snapshots
log "Retentions is set to $retention_days days, cleaning up older Snapshots in $destination_region"
cleanup_snapshots
