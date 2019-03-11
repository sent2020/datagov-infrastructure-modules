data "aws_route53_zone" "private" {
  name         = "${var.dns_zone}"
  private_zone = true
}

resource "aws_instance" "default" {
  count = "${var.instance_count}"

  ami                         = "${var.ami_id}"
  associate_public_ip_address = false
  instance_type               = "${var.instance_type}"
  key_name                    = "${var.key_name}"
  subnet_id                   = "${element(var.subnets, count.index)}"
  vpc_security_group_ids      = ["${var.security_groups}"]

  tags = "${merge(
    map(
      "Name", format(var.instance_name_format, count.index + 1),
      "env", var.env,
      "group", var.ansible_group
    ),
    var.tags)}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "default" {
  count = "${var.instance_count}"

  name    = "${format(var.instance_name_format, count.index + 1)}"
  zone_id = "${data.aws_route53_zone.private.zone_id}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${element(aws_instance.default.*.private_dns, count.index)}"]
}