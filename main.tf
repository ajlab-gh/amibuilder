provider "aws" {
  region = "ca-central-1"
}

variable "image_file" {
  type    = string
  default = "FMG_VM64_AWS-v7.4.6.M-build2588-FORTINET.out.OpenXen.zip"
}

variable "subnets_names" {
  type    = list(string)
  default = ["Public"]
}

variable "tag_name_prefix" {
  type    = string
  default = "terraform-test-fmg"
}

variable "vpc_cidr" {
  type    = string
  default = "10.7.0.0/16"
}

data "aws_region" "current" {}

resource "aws_vpc" "amibuilder" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.tag_name_prefix}-amibuilderVPC"
  }
}

resource "aws_security_group" "amibuilder" {
  name_prefix = "amibuilder"
  vpc_id      = aws_vpc.amibuilder.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.tag_name_prefix}-amibuilder-SG"
  }
}

resource "aws_subnet" "amibuilder_subnet" {
  count             = length(var.subnets_names)
  vpc_id            = aws_vpc.amibuilder.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 7)
  availability_zone = "${data.aws_region.current.name}a"
  tags = {
    Name = "${var.tag_name_prefix}-amibuilderSubnet-${var.subnets_names[count.index]}"
  }
}


###
resource "aws_network_interface" "amib-eni" {
  count                   = length(var.subnets_names)
  description             = var.subnets_names[count.index]
  private_ip_list_enabled = true
  private_ip_list         = [cidrhost(aws_subnet.amibuilder_subnet[count.index].cidr_block, 222)]
  subnet_id               = aws_subnet.amibuilder_subnet[count.index].id
  security_groups         = [aws_security_group.amibuilder.id]
  source_dest_check       = false
  tags = {
    Name = "${var.tag_name_prefix}-amib-eni-${var.subnets_names[count.index]}"
  }
}

# Create and attach the eip to public interface
resource "aws_eip" "amib-eni-eip-public" {
  depends_on        = [aws_instance.amibuilder]
  domain = "vpc"
  network_interface = aws_network_interface.amib-eni[0].id
  tags = {
    Name = "${var.tag_name_prefix}-amib-eni-eip-${var.subnets_names[0]}"
  }
}


resource "aws_internet_gateway" "amibuilder" {
  vpc_id = aws_vpc.amibuilder.id
  tags = {
    Name = "${var.tag_name_prefix}-amibuilderIGW"
  }
}

resource "aws_route_table" "amibuilder-public" {
  vpc_id = aws_vpc.amibuilder.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.amibuilder.id
  }
}

resource "aws_route_table_association" "amibuilder-public" {
  subnet_id      = aws_subnet.amibuilder_subnet[0].id
  route_table_id = aws_route_table.amibuilder-public.id
}



resource "aws_s3_bucket" "amibuilder" {
  bucket        = "amibuilder-bucket-${random_id.amibuilder_suffix.hex}"
  force_destroy = true
  tags = {
    Name = "${var.tag_name_prefix}-amib"
  }
}

resource "random_id" "amibuilder_suffix" {
  byte_length = 4
}


resource "aws_iam_role" "vmimport-trust-policy" {
  name               = "vmimport"
  assume_role_policy = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Principal": { "Service": "vmie.amazonaws.com" },
         "Action": "sts:AssumeRole",
         "Condition": {
            "StringEquals":{
               "sts:Externalid": "vmimport"
            }
         }
      }
   ]
}
EOF
}

resource "aws_iam_role_policy" "vmimport-role-policy" {
  name   = "vmimport"
  role   = aws_iam_role.vmimport-trust-policy.id
  policy = <<EOF
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect": "Allow",
         "Action": [
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket" 
         ],
         "Resource": [
            "arn:aws:s3:::${aws_s3_bucket.amibuilder.id}",
            "arn:aws:s3:::${aws_s3_bucket.amibuilder.id}/*"
         ]
      },
      {
         "Effect": "Allow",
         "Action": [
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket",
            "s3:PutObject",
            "s3:GetBucketAcl"
         ],
         "Resource": [
            "arn:aws:s3:::${aws_s3_bucket.amibuilder.id}",
            "arn:aws:s3:::${aws_s3_bucket.amibuilder.id}/*"
         ]
      },
      {
         "Effect": "Allow",
         "Action": [
            "ec2:ModifySnapshotAttribute",
            "ec2:CopySnapshot",
            "ec2:RegisterImage",
            "ec2:Describe*"
         ],
         "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ],
        "Resource": "*"
      }
   ]
}
EOF
}


resource "aws_iam_role" "amibuilder" {
  name = "amibuilder-iam-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "amibuilder" {
  name = "amibuilder-iam-profile"
  role = aws_iam_role.amibuilder.name
}

resource "aws_iam_role_policy" "amibuilder-iam_role_policy" {
  name   = "amibuilder-iam_role_policy"
  role   = aws_iam_role.amibuilder.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "iam:*",
                "s3:*",
                "ssm:*",
                "ec2:*",
                "kms:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}


data "aws_ssm_parameter" "amib-ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

# Create a Key Pair
resource "aws_key_pair" "aws_public_key" {
  key_name   = "aws_key_pair"  # Replace with your preferred key name
  public_key = file("aws_key_pair.pub")  # Replace with the path to your public key file
}

resource "aws_instance" "amibuilder" {
  ami                  = data.aws_ssm_parameter.amib-ami.value
  instance_type        = "t3.large"
  iam_instance_profile = aws_iam_instance_profile.amibuilder.id
  key_name             = aws_key_pair.aws_public_key.key_name
  # root disk
  root_block_device {
    volume_size           = "30"
    volume_type           = "gp2"
    delete_on_termination = true
  }
  tags = {
    Name = "${var.tag_name_prefix}-amib"
  }

  user_data = templatefile("${path.module}/userdata.sh", {
    bucket          = aws_s3_bucket.amibuilder.id
    build           = regex("build([[:digit:]]{4})", var.image_file)[0]
    prefix          = lower(substr(var.image_file, 0, 3))
    region          = "${data.aws_region.current.name}"
    source_filename = var.image_file

  })

  /*
  vpc_security_group_ids    = [aws_security_group.amibuilder.id]
  subnet_id                 = aws_subnet.amibuilder_subnet[1].id
  ##associate_public_ip_address = true  
*/

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.amib-eni[0].id
  }

}


resource "aws_network_interface_attachment" "amib_eni_attchment" {
  count                = length(var.subnets_names) - 1
  instance_id          = aws_instance.amibuilder.id
  network_interface_id = aws_network_interface.amib-eni[count.index + 1].id
  device_index         = count.index + 1
}


resource "aws_s3_object" "amibuilder_sourcefile" {
  bucket = aws_s3_bucket.amibuilder.bucket
  key    = var.image_file
  source = "${path.module}/${var.image_file}"
}


resource "aws_s3_object" "userdata-sh" {
  bucket = aws_s3_bucket.amibuilder.bucket
  key    = "/userdata.sh"
  content = templatefile("${path.module}/userdata.sh", {
    bucket          = aws_s3_bucket.amibuilder.id
    build           = regex("build([[:digit:]]{4})", var.image_file)[0]
    prefix          = lower(substr(var.image_file, 0, 3))
    region          = "${data.aws_region.current.name}"
    source_filename = var.image_file
  })
}


#############################################################################################################
# S3 Endpoint for license retreival without Internet Access
#############################################################################################################
resource "aws_vpc_endpoint" "s3-endpoint-vpc-amibuilder" {
  vpc_id          = aws_vpc.amibuilder.id
  service_name    = "com.amazonaws.${data.aws_region.current.name}.s3"
  route_table_ids = [aws_vpc.amibuilder.main_route_table_id]
  policy          = <<POLICY
{
    "Statement": [
        {
            "Action": "*",
            "Effect": "Allow",
            "Resource": "*",
            "Principal": "*"
        }
    ]
}
POLICY
  tags = {
    Name = "${var.tag_name_prefix}-s3-endpoint-vpc-amibuilder"
  }
}


data "aws_caller_identity" "current" {}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "caller_arn" {
  value = data.aws_caller_identity.current.arn
}

output "caller_user" {
  value = data.aws_caller_identity.current.user_id
}


output "amibuilder_instance_public_ip" {
  value = aws_instance.amibuilder.public_ip
}

output "amibuilder_instance_id" {
  value = aws_instance.amibuilder.id
}


output "aws_eip_amib-eni-eip-public_public_ip" {
  value = aws_eip.amib-eni-eip-public.public_ip
}

