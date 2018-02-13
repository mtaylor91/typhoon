# kube-apiserver Network Load Balancer DNS Record
resource "aws_route53_record" "k8s" {
  zone_id = "${var.dns_zone_id}"

  name = "${format("k8s.%s.", var.dns_zone)}"
  type = "A"

  # AWS recommends their special "alias" records for ELBs
  alias {
    name                   = "${aws_elb.k8s.dns_name}"
    zone_id                = "${aws_elb.k8s.zone_id}"
    evaluate_target_health = true
  }
}

# Kubernetes API Network Load Balancer
resource "aws_elb" "k8s" {
  name            = "${var.cluster_name}-k8s"
  subnets         = ["${aws_subnet.public.id}"]
  security_groups = ["${aws_security_group.k8s.id}"]

  listener {
    lb_port           = 443
    lb_protocol       = "tcp"
    instance_port     = 443
    instance_protocol = "tcp"
  }

  instances = ["${aws_instance.controllers.*.id}"]

  # Kubelet HTTP health check
  health_check {
    target              = "SSL:443"
    healthy_threshold   = 2
    unhealthy_threshold = 4
    timeout             = 5
    interval            = 6
  }

  idle_timeout                = 3600
  connection_draining         = true
  connection_draining_timeout = 300
}

# Kubernetes API Security Group

resource "aws_security_group" "k8s" {
  name          = "${var.cluster_name}-k8s"
  description   = "${var.cluster_name} k8s security group"

  vpc_id = "${aws_vpc.network.id}"

  tags = "${map("Name", "${var.cluster_name}-k8s")}"
}

resource "aws_security_group_rule" "k8s-api-cluster-http" {
  security_group_id = "${aws_security_group.k8s.id}"

  type          = "ingress"
  protocol      = "tcp"
  from_port     = 80
  to_port       = 80
  cidr_blocks   = ["${aws_instance.bastion.public_ip}/32"]
}

resource "aws_security_group_rule" "k8s-api-cluster-https" {
  security_group_id = "${aws_security_group.k8s.id}"

  type          = "ingress"
  protocol      = "tcp"
  from_port     = 443
  to_port       = 443
  cidr_blocks   = ["${aws_instance.bastion.public_ip}/32"]
}

resource "aws_security_group_rule" "k8s-api-protected-http" {
  security_group_id = "${aws_security_group.k8s.id}"

  type          = "ingress"
  protocol      = "tcp"
  from_port     = 80
  to_port       = 80
  cidr_blocks   = "${var.protected_access_cidrs}"
}

resource "aws_security_group_rule" "k8s-api-protected-https" {
  security_group_id = "${aws_security_group.k8s.id}"

  type          = "ingress"
  protocol      = "tcp"
  from_port     = 443
  to_port       = 443
  cidr_blocks   = "${var.protected_access_cidrs}"
}

resource "aws_security_group_rule" "k8s-api-egress-http" {
  security_group_id = "${aws_security_group.k8s.id}"

  type                     = "egress"
  protocol                 = "tcp"
  from_port                = 80
  to_port                  = 80
  source_security_group_id = "${aws_security_group.controller.id}"
}

resource "aws_security_group_rule" "k8s-api-egress-https" {
  security_group_id = "${aws_security_group.k8s.id}"

  type                     = "egress"
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  source_security_group_id = "${aws_security_group.controller.id}"
}

# Ingress Network Load Balancer
resource "aws_elb" "ingress" {
  name            = "${var.cluster_name}-ingress"
  subnets         = ["${aws_subnet.public.id}"]
  security_groups = ["${aws_security_group.ingress.id}"]

  listener {
    lb_port           = 80
    lb_protocol       = "tcp"
    instance_port     = 80
    instance_protocol = "tcp"
  }

  listener {
    lb_port           = 443
    lb_protocol       = "tcp"
    instance_port     = 443
    instance_protocol = "tcp"
  }

  # Ingress Controller HTTP health check
  health_check {
    target              = "HTTP:10254/healthz"
    healthy_threshold   = 2
    unhealthy_threshold = 4
    timeout             = 5
    interval            = 6
  }

  connection_draining         = true
  connection_draining_timeout = 300
}

# Ingress Security Group

resource "aws_security_group" "ingress" {
  name          = "${var.cluster_name}-ingress"
  description   = "${var.cluster_name} ingress security group"

  vpc_id = "${aws_vpc.network.id}"

  tags = "${map("Name", "${var.cluster_name}-ingress")}"
}

resource "aws_security_group_rule" "ingress-public-http" {
  security_group_id = "${aws_security_group.ingress.id}"

  type          = "ingress"
  protocol      = "tcp"
  from_port     = 80
  to_port       = 80
  cidr_blocks   = "${var.public_access_cidrs}"
}

resource "aws_security_group_rule" "ingress-public-https" {
  security_group_id = "${aws_security_group.ingress.id}"

  type          = "ingress"
  protocol      = "tcp"
  from_port     = 443
  to_port       = 443
  cidr_blocks   = "${var.public_access_cidrs}"
}

resource "aws_security_group_rule" "ingress-egress-http" {
  security_group_id = "${aws_security_group.ingress.id}"

  type                     = "egress"
  protocol                 = "tcp"
  from_port                = 80
  to_port                  = 80
  source_security_group_id = "${aws_security_group.worker.id}"
}

resource "aws_security_group_rule" "ingress-egress-https" {
  security_group_id = "${aws_security_group.ingress.id}"

  type                     = "egress"
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  source_security_group_id = "${aws_security_group.worker.id}"
}
