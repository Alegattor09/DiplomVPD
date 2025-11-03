# Security_group 
resource "yandex_vpc_security_group" "internal" {
  name       = "internal-rules"
  network_id = yandex_vpc_network.dipnet.id
  
  ingress {
    protocol       = "ANY"
    description    = "allow any connection from internal subnets"
	  predefined_target = "self_security_group"
  }

  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }

  ingress {
    protocol       = "TCP"
    description    = "zabbix server receive data from agent on server port"
    v4_cidr_blocks = ["10.4.4.5/32"]
    port           = 10050
  }

  ingress {
    protocol       = "TCP"
    description    = "Elasticsearch REST API for internal services"
    v4_cidr_blocks = ["10.0.0.0/8"]
    port           = 9200
 }

  ingress {
    protocol       = "TCP"
    description    = "Kibana admin access"
    v4_cidr_blocks = ["10.4.4.0/27"]
    port           = 5601
 }

   ingress {
    protocol    = "ANY"
    description = "internal traffic private network"
    v4_cidr_blocks = ["10.0.0.0/8"]
  }
  egress {
    protocol       = "ANY"
    description    = "allow any outgoing connection private network"
    v4_cidr_blocks = ["10.0.0.0/8"]
  }

}


resource "yandex_vpc_security_group" "public-bastion" {
  name       = "public-bastion-rules"
  network_id = yandex_vpc_network.dipnet.id

  ingress {
    protocol       = "TCP"
    description    = "ssh_bastion"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  ingress {
    protocol       = "ICMP"
    description    = "allow ping"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}


resource "yandex_vpc_security_group" "public-zabbix" {
  name       = "public-zabbix-rules"
  network_id = yandex_vpc_network.dipnet.id

  ingress {
    protocol       = "TCP"
    description    = "zabbix server receive data from agents"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 10051
  }

  ingress {
    protocol       = "TCP"
    description    = "allow zabbix connections from internet"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  } 

  ingress {
    protocol       = "ICMP"
    description    = "allow ping"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "zabbix server receive data on agent port"
    v4_cidr_blocks = ["10.0.0.0/8"]
    port           = 10051
  }

  egress {
    protocol       = "ANY"
    description    = "allow any outgoing connection"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "yandex_vpc_security_group" "public-kibana" {
  name       = "public-kibana-rules"
  network_id = yandex_vpc_network.dipnet.id

  ingress {
    protocol       = "TCP"
    description    = "allow kibana connections from internet"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 5601
  }

  ingress {
    protocol       = "ICMP"
    description    = "allow ping"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    description    = "allow any outgoing connection"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "yandex_vpc_security_group" "public-load-balancer" {
  name       = "public-load-balancer-rules"
  network_id = yandex_vpc_network.dipnet.id

  ingress {
    protocol          = "ANY"
    description       = "Health checks"
    v4_cidr_blocks    = ["0.0.0.0/0"]
    predefined_target = "loadbalancer_healthchecks"
  }

  ingress {
    protocol       = "TCP"
    description    = "allow HTTP connections from internet"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol       = "ICMP"
    description    = "allow ping"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    description    = "allow any outgoing connection"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
