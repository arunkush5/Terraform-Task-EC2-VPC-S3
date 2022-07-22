terraform {
  required_providers{
      aws = {
      }
  }
}

provider "aws" {
    region = "ap-south-1"
    profile = "user-arun"
}


resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh_key_pair" {
  key_name   = "k2-terra-instance.pem"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDDH1I59m7qgHEX8+2mmnsP2c3N0nqAGGFOnZEKGaIjhuwF9paYKYOeM+k+FrICfxEeo9g3P31aqPP+OU91ED3yNBL0VqbcPSmomDWMjvLGPTINJpPs1pbxn61wdfJrwlrNEo8OAYRSp2De2j9cFaWibHDe1idW1G1gnRrNmIBe11mBclaFcKZMC6M5cyVrNWBCifRpbFbIqvBSKPoi8g1IIB8JhEuBu7XnHzdsem3Zmm0E0gMXGgxck3n0riv50lX4686j4HAgGafclmQYsBZtPg17utksKJKv1WNDhvojw9Z5c4rgxlWK+JbbthfXs8pHge6sRcmFxNujT6jHINhcHGPRt9V4vCfwlL0k+ZIyI2o200S30nsZIzA8SADbqkqYBnhvpsxTb81PaK7URcG7fDfwlenUN0BZ6GAahBpKLQBL7HP2Nh3STy6TWNUcRY5QoXjmV4bkuj4XF/niD5GiH+UgfwDRyDUspBAMRHT31Mp/K6xWTDUf3clGsZLKfv8= terra-user"
 }

# Create our VPC where all of our resources will live
resource "aws_vpc" "test_vpc" {
  cidr_block       = "10.0.0.0/24"

  tags = {
    Name = "test_vpc"
  }
}

# Create a subnet to place our instance in
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.test_vpc.id
  cidr_block        = "10.0.0.0/24"

  tags = {
    Name = "public_vpc_subnet"
  }
}

# We need the instance to be publicly accessible thus we setup an internate gateway
resource "aws_internet_gateway" "public_internet_gateway" {
  vpc_id = aws_vpc.test_vpc.id
tags = {
    Name = "test_internet_gateway"
  }
}

# Create a route table so the traffic knows where to go
resource "aws_route_table" "public_route_table" {
  vpc_id             = aws_vpc.test_vpc.id
route {
    cidr_block       = "0.0.0.0/0"
    gateway_id       = aws_internet_gateway.public_internet_gateway.id
  }
tags = {
    Name             = "public_route_table"
  }
}

# Associate our rate table with our subnet
resource "aws_route_table_association" "public_subnet_route_association" {
  subnet_id          = aws_subnet.public_subnet.id
  route_table_id     = aws_route_table.public_route_table.id
}

# This will pull our public IP address and store it
data "http" "icanhazip" {
   url               = "https://icanhazip.com"
}

# Now we create a security rule that allows inbound SSH from only our IP address
# In the egress section below we're allowing outbound traffic to any public IP. You my want to change this according to your needs
resource "aws_security_group" "allow_ssh" {
  vpc_id             = aws_vpc.test_vpc.id

  ingress {
    description      = "Inbound SSH access from my IP"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [ 
      "${chomp(data.http.icanhazip.body)}/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name             = "allow_ssh"
  }
 }


# Create our instance based on the information we've filled out so far
resource "aws_instance" "Testing_instance" {
  ami                         = "ami-068257025f72f470d"
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.ssh_key_pair.id
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true 
  user_data                   = file("./setup.sh")

  root_block_device {
    volume_size           = 30
    delete_on_termination = true # The root volume will be deleted when you run 'terraform destroy'. Change this to false to prevent that.
}

  tags = {
    Name = "instance-created-by-terraform"
  }
}

# The user to which we will grant access to s3
#resource "aws_iam_user" "user-arun" {
#  name          = "s3-user-arun"
#  path          = "/"
#}

# Create an IAM role that we'll assign later on
#resource "aws_iam_role" "user-arun-role" {
# name = "s3-user-arun-role"
#  assume_role_policy = <<EOF
#{
# "Version": "2012-10-17",
#  "Statement": [
#    {
#      "Action": "sts:AssumeRole",
#      "Principal": {
#        "Service": "s3.amazonaws.com"
#      },
#      "Effect": "Allow",
#      "Sid": ""
#    }
#  ]
#}
#EOF
#}

# This is the policy we're attaching to the user we're creating that will allow us to access the S3 bucket and mount it via s3fs to the instance
#resource "aws_iam_policy" "user-arun-policy" {
# name = "user-arun-policy"

# policy = <<EOF
#{
#  "Version":"2012-10-17",
#  "Statement": [
#    { "Effect": "Allow",
#      "Action": [
#      "s3:GetBucketLocation",
#      "s3:ListAllMyBuckets" 
#     ],
#      "Resource": "arn:aws:s3:::*" 
#},
#   { "Effect": "Allow",
#      "Action": ["s3:ListBucket"],
#      "Resource": ["arn:aws:s3:::var.bucket_name"]
#},
#    { "Effect": "Allow",
#      "Action": [
#        "s3:PutObject",
#        "s3:GetObject",
#        "s3:DeleteObject"
#      ],
#      "Resource": ["arn:aws:s3:::var.bucket_name/*"]
#    }
#  ]
#}
#EOF
#}

# Attach our policy to our role with the correct ARN
#resource "aws_iam_role_policy_attachment" "user-arun-policy-attach" {
#  role = aws_iam_role.user-arun-role.name
#  policy_arn = aws_iam_policy.user-arun-policy.arn
#}

# Attach our policy to our user with the correct ARN
#resource "aws_iam_user_policy_attachment" "arun-user-attach" {
#  user = aws_iam_user.user-arun.name
#  policy_arn = aws_iam_policy.user-arun-policy.arn
#}

# Create the access key
#resource "aws_iam_access_key" "ssh_test_key" {
#  user = aws_iam_user.user-arun.name
#}

# Create the bucket for storing our files
resource "aws_s3_bucket" "terra-bucket-arun" {
  bucket_prefix = "testing-buckt"
  force_destroy = false # Prevents the bucket from being deleted if there are files in it and you run 'terraform destroy'. Change to true to bypass this
}
