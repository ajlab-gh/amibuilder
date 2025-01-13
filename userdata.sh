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
SOURCE_FILENAME_QCOW2="$PREFIX.qcow2"
BUCKET="${bucket}"
REGION="${region}"
BUILD="${build}"
DESTINATION_FILENAME="$PREFIX$BUILD.raw"

echo "copying userdata script to /root"
aws s3 cp --region $REGION s3://$BUCKET/userdata.sh .

echo "copying from S3 bucket $BUCKET"
aws s3 cp --region $REGION s3://$BUCKET/$SOURCE_FILENAME .

echo unziping
unzip $SOURCE_FILENAME

echo "converting to raw file format"
qemu-img convert -O raw $SOURCE_FILENAME_QCOW2 $DESTINATION_FILENAME

echo "copying to S3 bucket"
aws s3 cp --quiet --region $REGION $DESTINATION_FILENAME s3://$BUCKET/$DESTINATION_FILENAME

echo "import raw file as ec2 snapshot"
#aws ec2 import-snapshot --region $REGION --description "$PREFIX$BUILD-snapshot" --disk-container Format=raw,UserBucket="{S3Bucket=$BUCKET,S3Key=$DESTINATION_FILENAME}"
IMPORT_TASK_ID=$(aws ec2 import-snapshot --region $REGION --description "$PREFIX$BUILD-snapshot" --disk-container Format=raw,UserBucket="{S3Bucket=$BUCKET,S3Key=$DESTINATION_FILENAME}" --query 'ImportTaskId' --output text )

#--tag-specifications 'ResourceType=snapshot,Tags=[{Key=Name,Value=$PREFIX$BUILD-snapshot}]'


echo "waiting for snapshot import $IMPORT_TASK_ID"
aws ec2 wait snapshot-imported --region $REGION --import-task-ids $IMPORT_TASK_ID

echo -n "grabing snashotid "
SNAPSHOT_ID=$(aws ec2 describe-import-snapshot-tasks --region $REGION --import-task-ids $IMPORT_TASK_ID --query 'ImportSnapshotTasks[0].SnapshotTaskDetail.SnapshotId' --output text)
echo "$SNAPSHOT_ID"

echo "Register EC2 Snapshot as Amazon Machine Image (AMI)"
aws ec2 register-image --region $REGION --name "$PREFIX$BUILD" --architecture x86_64 --root-device-name /dev/sda1 --virtualization-type hvm --ena-support --block-device-mappings DeviceName="/dev/sda1","Ebs={SnapshotId=$SNAPSHOT_ID,DeleteOnTermination=true,VolumeType=standard}"

