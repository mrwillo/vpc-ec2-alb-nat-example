terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "example-org-5ed821"

    workspaces {
      name = "vpc-ec2-alb-nat-example"
    }
  }
}