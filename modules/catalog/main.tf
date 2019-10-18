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
  source = "../postgresdb"

  db_name               = "catalog_db"
  db_password           = "${var.db_password}"
  database_subnet_group = "${var.database_subnet_group}"
  db_username           = "catalog_master"
  env                   = "${var.env}"
  vpc_id                = "${var.vpc_id}"
}

module "web" {
  source = "../web"

  ami_id           = "${data.aws_ami.ubuntu.id}"
  ansible_group    = "catalog_web"
  bastion_host     = "${var.bastion_host}"
  dns_zone_public  = "${var.dns_zone_public}"
  dns_zone_private = "${var.dns_zone_private}"
  env              = "${var.env}"
  instance_count   = "${var.web_instance_count}"
  instance_type    = "${var.web_instance_type}"
  key_name         = "${var.key_name}"
  name             = "catalog"
  private_subnets  = "${var.subnets_private}"
  public_subnets   = "${var.subnets_public}"
  security_groups  = "${concat(var.security_groups, list(module.db.security_group))}"
  vpc_id           = "${var.vpc_id}"

  lb_target_groups = [{
    name              = "catalog-web-${var.env}"
    backend_protocol  = "HTTP"
    backend_port      = "80"
    health_check_path = "/api/action/status_show"
  }]
}

resource "aws_security_group" "harvester" {
  name        = "${var.env}-catalog-harvester-tf"
  description = "Catalog harvester security group"
  vpc_id      = "${var.vpc_id}"

  # TODO all the hosts should be able to talk to ubuntu 80/443 for updates. Not
  # sure where that security group should live. Maybe in VPC as a default sg?
  #
  # Allow outbound access for harvesting. For now on just 80/443
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    env = "${var.env}"
  }
}

module "harvester" {
  source = "../stateless"

  ami_id               = "${data.aws_ami.ubuntu.id}"
  ansible_group        = "catalog_harvester"
  bastion_host         = "${var.bastion_host}"
  dns_zone             = "${var.dns_zone_private}"
  env                  = "${var.env}"
  instance_count       = "${var.harvester_instance_count}"
  instance_name_format = "catalog-harvester%dtf"
  instance_type        = "${var.harvester_instance_type}"
  key_name             = "${var.key_name}"
  subnets              = "${var.subnets_private}"
  vpc_id               = "${var.vpc_id}"

  security_groups = "${concat(var.security_groups, list(module.db.security_group, aws_security_group.harvester.id))}"
}