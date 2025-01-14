#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
#Wait for the repo 
echo "Waiting for internet access"
curl --retry 20 -s -o /dev/null "https://aws.amazon.com"

cd /root
pwd
#removing and upgrading aws cli to version 2
yum -y  remove awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

#installing qemu-img
yum -y install qemu-img


#Variables
PREFIX="${prefix}"
SOURCE_FILENAME="${source_filename}"
BUCKET="${bucket}"
REGION="${region}"
BUILD="${build}"
DESTINATION_FILENAME="$PREFIX$BUILD.raw"

# Make sure files are in s3
check_s3_file() {
    local bucket=$1
    local file=$2
    local region=$3
    local max_attempts=20
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if aws s3 ls "s3://$bucket/$file" --region "$region" >/dev/null 2>&1; then
            echo "Confirmed: $file exists in S3 bucket"
            return 0
        fi
        echo "Attempt $attempt: Waiting for $file to be available in S3..."
        sleep 10
        attempt=$((attempt + 1))
    done
    echo "Error: Failed to find $file in S3 bucket after $max_attempts attempts"
    exit 1
}

# copy files from s3
echo "Verifying and copying userdata script to /root"
check_s3_file "$BUCKET" "userdata.sh" "$REGION"
aws s3 cp --region "$REGION" "s3://$BUCKET/userdata.sh" . || exit 1

echo "Verifying and copying from S3 bucket $BUCKET"
check_s3_file "$BUCKET" "$SOURCE_FILENAME" "$REGION"
aws s3 cp --region "$REGION" "s3://$BUCKET/$SOURCE_FILENAME" . || exit 1

# unzip the archive
echo unziping
unzip $SOURCE_FILENAME

# dynamically find the cqow2 image based on size (datadisk cqow is smaller)
find_largest_qcow2() {
    local largest_file=""
    local max_size=0
    
    # First check if any qcow2 files exist silently
    if ! ls *.qcow2 >/dev/null 2>&1; then
        echo "Error: No qcow2 files found!" >&2
        exit 1
    fi
    
    # Find largest file without extra output
    for file in *.qcow2; do
        if [ -f "$file" ]; then
            local size=$(stat -c%s "$file")
            if [ "$size" -gt "$max_size" ]; then
                max_size=$size
                largest_file=$file
            fi
        fi
    done
    
    if [ -z "$largest_file" ]; then
        echo "Error: No valid qcow2 files found!" >&2
        exit 1
    fi
    
    # Only output the filename itself
    printf "%s" "$largest_file"
}

# In the main script:
echo "Finding largest qcow2 file..."
SOURCE_FILENAME_QCOW2=$(find_largest_qcow2)
if [ $? -ne 0 ]; then
    echo "Failed to find qcow2 file"
    exit 1
fi

echo "Using qcow2 file: $SOURCE_FILENAME_QCOW2"
echo "Converting $SOURCE_FILENAME_QCOW2 to raw file format"
qemu-img convert -O raw "$SOURCE_FILENAME_QCOW2" "$DESTINATION_FILENAME"

echo "copying to S3 bucket"
aws s3 cp --quiet --region $REGION $DESTINATION_FILENAME s3://$BUCKET/$DESTINATION_FILENAME

echo "import raw file as ec2 snapshot"
IMPORT_TASK_ID=$(aws ec2 import-snapshot --region $REGION --description "$PREFIX$BUILD-snapshot" --disk-container Format=raw,UserBucket="{S3Bucket=$BUCKET,S3Key=$DESTINATION_FILENAME}" --query 'ImportTaskId' --output text )

echo "waiting for snapshot import $IMPORT_TASK_ID"
aws ec2 wait snapshot-imported --region $REGION --import-task-ids $IMPORT_TASK_ID

echo -n "grabbing snashotid "
SNAPSHOT_ID=$(aws ec2 describe-import-snapshot-tasks --region $REGION --import-task-ids $IMPORT_TASK_ID --query 'ImportSnapshotTasks[0].SnapshotTaskDetail.SnapshotId' --output text)
echo "$SNAPSHOT_ID"

echo "Register EC2 Snapshot as Amazon Machine Image (AMI)"
aws ec2 register-image --region $REGION --name "$PREFIX$BUILD" --architecture x86_64 --root-device-name /dev/sda1 --virtualization-type hvm --ena-support --block-device-mappings DeviceName="/dev/sda1","Ebs={SnapshotId=$SNAPSHOT_ID,DeleteOnTermination=true,VolumeType=standard}"

