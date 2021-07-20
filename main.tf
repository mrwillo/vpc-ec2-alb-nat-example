locals {
  user_data = <<EOF
#!/bin/bash
sudo su

yum update -y
yum install -y httpd.x86_64
systemctl start httpd.service
systemctl enable httpd.service
echo "hello world from $(hostname -f) >> /var/www/html/index.html
EOF
}
module "vpc" {
    source = "terraform-aws-modules/vpc/aws"

    name = "duy-vpc"
    cidr = "10.0.0.0/16"
    azs=["us-east-1a","us-east-1b","us-east-1c"]
    # private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    public_subnets = ["10.0.101.0/24","10.0.102.0/24","10.0.103.0/24"]

    enable_nat_gateway = false
    # single_nat_gateway = false
    # reuse_nat_ips      = true
    # external_nat_ip_ids =    "${aws_eip.nat.*.id}"

    tags = {
        terraform = "true"
        Environment = "dev"
    }
}

# resource "aws_eip" "nat" {
#     count = 3
#     vpc = true
# }

data "aws_vpc" "selected" {
    id = "${module.vpc.vpc_id}"
}

data "aws_subnet_ids" "all" {
  vpc_id = "${data.aws_vpc.selected.id}"
 
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name = "name"

    values = [
      "amzn2-ami-hvm-*-x86_64-gp2",
    ]
  }
}

module "security_group" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "example"
  description = "Security group for example usage with EC2 instance"
  vpc_id      = "${data.aws_vpc.selected.id}"

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "all-icmp"]
  egress_rules        = ["all-all"]
}

module "security_group_lvl2"{
  source = "terraform-aws-modules/security-group/aws"

  name        = "sg_alb_lvl2"
  description = "Security group for example usage with EC2 instance"
  vpc_id      = "${data.aws_vpc.selected.id}"

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["https-443-tcp", "all-icmp"]
  egress_rules        = ["all-all"]
}

module "security_group_lvl1"{
  source = "terraform-aws-modules/security-group/aws"

  name        = "sg_alb_lvl1"
  description = "Security group for example usage with EC2 instance"
  vpc_id      = "${data.aws_vpc.selected.id}"

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "all-icmp"]
  egress_rules        = ["all-all"]
}

# resource "aws_eip" "this" {
#   vpc      = true
#   instance = "${module.ec2.id[0]}"
# }

module "ec2_cluster" {
  source = "terraform-aws-modules/ec2-instance/aws"

  for_each = data.aws_subnet_ids.all.ids
  name                        = "example + ${each.value}"
  ami                         = "${data.aws_ami.amazon_linux.id}"
  instance_type               = "t2.micro"
  subnet_id                   = each.value
  vpc_security_group_ids      = ["${module.security_group.security_group_id}"]
  associate_public_ip_address = true
  user_data_base64 = base64encode(local.user_data)
  key_name = aws_key_pair.dytn.key_name
}

resource "aws_lb" "alb-lv1" {
  name = "lb-lvl1"
  load_balancer_type = "application"
  security_groups = ["${module.security_group_lvl1.security_group_id}"] 
  subnets = data.aws_subnet_ids.all.ids
}

resource "aws_lb" "alb-lv2" {
  name = "lb-lvl2"
  load_balancer_type = "application"
  security_groups = ["${module.security_group_lvl2.security_group_id}"] 
  subnets = data.aws_subnet_ids.all.ids
}

resource "aws_key_pair" "dytn" {
    key_name = "dytn-key"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDeskIzxuKiWySyiNRRFt22M9J++Ne4KaDAZL/a4PpaOTeNRJVitKq/raGwtwjEZU0CeP04DBXkN2rbffg8KDExNGm8BuXXwwbCKQ/xEnRzusY446Jg/FF88cs2OeknbSYADMb2vc0IzxQs9KEjdyAGXObJrxMRuopxRSdW/yGd8tlr48i7BMTNj/NKCxIoyucqRZxPPzFbEPzu2oXCmjDIef4f2ujxpuqxPZxAkztHNEmR184x91m9TZF5IDtjeHHPpXPQQKRJMx/X0Xbp98CvDi2jdDz3YV2rrbsOQricKVbTHqdmiEQuNTsnmN3JVsDT2zGNWzr4ImA5BCnhvGKAABAz71wylQcaHziZI6RojkkV/icAqn2ijzdiqxRJyQ8oRtFlN1hzSdEI4rAUn40nS8Le+6C/eky4I9OjriaihKYU8KSIkCm+byKDEiT9EAJlcZ7T+TQV57ljkw1NY9+9s89XV7t7zG82ofEnr3A4nxZk/U5frSqYO1Gl7TO3NYCHkpxUKHpGJFkTRkXooS8KrC1OvSOYtCzz0Hg2fOF/q968ncv90tMelZ8xy1TKsqWAZBASQx122m03Nc7rke17TLEG1dBUMxVVk6O1nQgAPKIZWDRmyHlDWesYet4MPfcT4DcCDxyDpLIdfRMkwuNcJYxF6EU5BnUB8JlnNumAnw== dytn@gft.com"
}