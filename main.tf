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
      "amzn-ami-hvm-*-x86_64-gp2",
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
}

# module "ec2_cluster" {
#   source = "terraform-aws-modules/ec2-instance/aws"

#   name           = "my-cluster"
#   instance_count = 5
  
#   ami                    = "ami-ebd02392"
#   instance_type          = "t2.micro"
#   key_name               = "user1"
#   monitoring             = true
#   vpc_security_group_ids = ["sg-12345678"]
#   subnet_id              = "subnet-eddcdzz4"

#   tags = {
#     Terraform = "true"
#     Environment = "dev"
#   }
# }