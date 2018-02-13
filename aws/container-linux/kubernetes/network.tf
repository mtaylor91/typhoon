data "aws_availability_zones" "all" {}

# Network VPC, gateway, and routes

resource "aws_vpc" "network" {
  cidr_block                       = "${var.host_cidr}"
  assign_generated_ipv6_cidr_block = true
  enable_dns_support               = true
  enable_dns_hostnames             = true

  tags = "${map("Name", "${var.cluster_name}")}"
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = "${aws_vpc.network.id}"

  tags = "${map("Name", "${var.cluster_name}")}"
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.network.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gateway.id}"
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = "${aws_internet_gateway.gateway.id}"
  }

  tags = "${map("Name", "${var.cluster_name}-public-route-table")}"
}

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.network.id}"

  route {
    cidr_block = "0.0.0.0/0"
    instance_id = "${aws_instance.bastion.id}"
  }

  route {
    ipv6_cidr_block = "::/0"
    instance_id     = "${aws_instance.bastion.id}"
  }

  tags = "${map("Name", "${var.cluster_name}-private-route-table")}"
}

# Public Subnet

resource "aws_subnet" "public" {
  vpc_id            = "${aws_vpc.network.id}"
  availability_zone = "${data.aws_availability_zones.all.names[0]}"

  cidr_block                      = "${cidrsubnet(var.host_cidr, 4, 0)}"
  ipv6_cidr_block                 = "${cidrsubnet(aws_vpc.network.ipv6_cidr_block, 8, 0)}"
  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = true

  tags = "${map("Name", "${var.cluster_name}-public")}"
}

resource "aws_route_table_association" "public" {
  route_table_id = "${aws_route_table.public.id}"
  subnet_id      = "${aws_subnet.public.id}"
}

# Private Subnets (one per AZ)

resource "aws_subnet" "private" {
  count = "${length(data.aws_availability_zones.all.names)}"

  vpc_id            = "${aws_vpc.network.id}"
  availability_zone = "${data.aws_availability_zones.all.names[count.index]}"

  cidr_block                      = "${cidrsubnet(var.host_cidr, 4, count.index + 1)}"
  ipv6_cidr_block                 = "${cidrsubnet(aws_vpc.network.ipv6_cidr_block, 8, count.index + 1)}"
  map_public_ip_on_launch         = false
  assign_ipv6_address_on_creation = true

  tags = "${map("Name", "${var.cluster_name}-private-${count.index}")}"
}

resource "aws_route_table_association" "private" {
  count = "${length(data.aws_availability_zones.all.names)}"

  route_table_id = "${aws_route_table.private.id}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
}
