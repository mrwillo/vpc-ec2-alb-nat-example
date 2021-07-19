terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "company"

    workspaces {
      name = "vpc-ec2-alb-nat-example"
    }
  }
}