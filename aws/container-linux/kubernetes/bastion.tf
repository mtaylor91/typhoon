
# Bastion instance
resource "aws_instance" "bastion" {
  tags = {
    Name = "${var.cluster_name}-bastion",
    KubernetesCluster = "${var.cluster_name}"
  }

  instance_type = "${var.bastion_type}"

  ami = "${data.aws_ami.coreos.image_id}"
  user_data = "${data.ct_config.bastion_ign.rendered}"

  # storage
  root_block_device {
    volume_type = "standard"
    volume_size = "${var.disk_size}"
  }

  # network
  associate_public_ip_address = true
  source_dest_check           = false
  subnet_id                   = "${aws_subnet.public.id}"
  vpc_security_group_ids      = ["${aws_security_group.bastion.id}"]
}

# Bastion Container Linux Config (source)
data "template_file" "bastion_config" {
  template = "${file("${path.module}/cl/bastion.yaml.tmpl")}"

  vars = {
    ssh_authorized_key = "${var.ssh_authorized_key}"
  }
}

# Bastion Container Linux Config (generated)
data "ct_config" "bastion_ign" {
  content = "${data.template_file.bastion_config.rendered}"
  pretty_print = false
}

# Bastion AWS security group

resource "aws_security_group" "bastion" {
  name          = "${var.cluster_name}-bastion"
  description   = "${var.cluster_name} bastion security group"

  vpc_id = "${aws_vpc.network.id}"

  tags = "${map("Name", "${var.cluster_name}-bastion")}"
}

resource "aws_security_group_rule" "bastion-icmp" {
  security_group_id = "${aws_security_group.bastion.id}"

  type          = "ingress"
  protocol      = "icmp"
  from_port     = 0
  to_port       = 0
  cidr_blocks   = "${var.protected_access_cidrs}"
}

resource "aws_security_group_rule" "bastion-ssh" {
  security_group_id = "${aws_security_group.bastion.id}"

  type          = "ingress"
  protocol      = "tcp"
  from_port     = 22
  to_port       = 22
  cidr_blocks   = "${var.protected_access_cidrs}"
}

resource "aws_security_group_rule" "bastion-ingress" {
  security_group_id = "${aws_security_group.bastion.id}"

  type             = "ingress"
  protocol         = "-1"
  from_port        = 0
  to_port          = 0
  cidr_blocks      = ["${var.host_cidr}"]
}

resource "aws_security_group_rule" "bastion-egress" {
  security_group_id = "${aws_security_group.bastion.id}"

  type             = "egress"
  protocol         = "-1"
  from_port        = 0
  to_port          = 0
  cidr_blocks      = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
}
