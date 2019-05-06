provider "aws" {
  region = "${var.aws_region}"
}

terraform {
  backend "s3" {}
}

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config {
    bucket = "datagov-terraform-state"
    key    = "${var.env}/vpc/terraform.tfstate"
    region = "${var.aws_region}"
  }
}

data "terraform_remote_state" "jumpbox" {
  backend = "s3"

  config {
    bucket = "datagov-terraform-state"
    key    = "${var.env}/jumpbox/terraform.tfstate"
    region = "${var.aws_region}"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["${var.ami_filter_name}"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = ["099720109477"] # Canonical
}

module "db" {
  source = "../modules/mysql"

  db_name               = "dashboard_db"
  db_password           = "${var.db_password}"
  database_subnet_group = "${data.terraform_remote_state.vpc.database_subnet_group}"
  db_username           = "dashboard_master"
  env                   = "${var.env}"
  vpc_id                = "${data.terraform_remote_state.vpc.vpc_id}"
}

module "web" {
  source = "../modules/web"

  ami_id           = "${data.aws_ami.ubuntu.id}"
  ansible_group    = "dashboard_web"
  bastion_host     = "${data.terraform_remote_state.jumpbox.jumpbox_dns}"
  dns_zone_public  = "${data.terraform_remote_state.vpc.dns_zone_public}"
  dns_zone_private = "${data.terraform_remote_state.vpc.dns_zone_private}"
  env              = "${var.env}"
  instance_count   = "${var.web_instance_count}"
  key_name         = "${var.key_name}"
  name             = "dashboard"
  private_subnets  = "${data.terraform_remote_state.vpc.private_subnets}"
  public_subnets   = "${data.terraform_remote_state.vpc.public_subnets}"
  vpc_id           = "${data.terraform_remote_state.vpc.vpc_id}"

  security_groups = [
    "${data.terraform_remote_state.jumpbox.security_group_id}",
    "${module.db.security_group}",
  ]

  lb_target_groups = [{
    name              = "dashboard-web-${var.env}"
    backend_protocol  = "HTTP"
    backend_port      = "443"
    health_check_path = "/"
  }]
}
