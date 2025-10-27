#Основные конфигурации виртуальных машин
#bastion
resource "yandex_compute_instance" "bastion" {
  name                      = "vm-bastion"
  hostname                  = "bastion"
  zone                      = "ru-central1-b" 
  allow_stopping_for_update = true
  platform_id               = "standard-v3" 

  resources {
    cores  = 2
    memory = 2
    core_fraction = 20
  }

  boot_disk {
    disk_id     = "${yandex_compute_disk.disk-bastion.id}"
    }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public.id
	dns_record {
      fqdn = "bastion.srv."
    ttl = 300
    }
    nat                = true
    security_group_ids = [yandex_vpc_security_group.internal.id, yandex_vpc_security_group.public-bastion.id]
    ip_address         = "10.4.4.4"
  }

  metadata = {
    user-data = "${file("./cloud-init.yml")}"
 
  }

  scheduling_policy {  
    preemptible = true
    
  }
}


#WEB servers
resource "yandex_compute_instance" "web-1" {
  name                      = "vm-web-1"
  hostname                  = "web-1"
  zone                      = "ru-central1-a"
  allow_stopping_for_update = true
  platform_id               = "standard-v3"

  resources {
    cores  = 2
    memory = 2
    core_fraction = 20
  }

  boot_disk {
    disk_id     = "${yandex_compute_disk.disk-web-1.id}"
    }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet_web-1.id
	dns_record {
      fqdn = "web1.srv."
    ttl = 300
    }
    security_group_ids = [yandex_vpc_security_group.internal.id]
    ip_address         = "10.1.1.3"
  }
  metadata = {
    user-data = "${file("./cloud-init.yml")}"
  }

  scheduling_policy {  
    preemptible = true
  }
}

resource "yandex_compute_instance" "web-2" {
  name                      = "vm-web-2"
  hostname                  = "web-2"
  zone                      = "ru-central1-b"
  allow_stopping_for_update = true
  platform_id               = "standard-v3" 

  resources {
    cores  = 2
    memory = 2
    core_fraction = 20
  }

  boot_disk {
    disk_id     = "${yandex_compute_disk.disk-web-2.id}"
    }
    
  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet_web-2.id
	dns_record {
      fqdn = "web2.srv."
    ttl = 300
    }
    security_group_ids = [yandex_vpc_security_group.internal.id]
    ip_address         = "10.2.2.3"
  }
  metadata = {
    user-data = "${file("./cloud-init.yml")}"
  }

  scheduling_policy {  
    preemptible = true
  }
}


#zabbix
resource "yandex_compute_instance" "zabbix" {
  name                      = "vm-zabbix"
  hostname                  = "zabbix"
  zone                      = "ru-central1-b"
  allow_stopping_for_update = true
  platform_id               = "standard-v3"

  resources {
    cores  = 2
    memory = 2
    core_fraction = 20
  }

  boot_disk {
    disk_id     = "${yandex_compute_disk.disk-zabbix.id}"
    }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public.id
	dns_record {
      fqdn = "zabbix.srv."
    ttl = 300
    }
    nat                = true
    security_group_ids = [yandex_vpc_security_group.internal.id, yandex_vpc_security_group.public-zabbix.id]
    ip_address         = "10.4.4.5"
  }

  metadata = {
    user-data = "${file("./cloud-init.yml")}"
  }

  scheduling_policy {  
    preemptible = true
  }
}


# elastic
resource "yandex_compute_instance" "elastic" {
  name                      = "vm-elastic"
  hostname                  = "elastic"
  zone                      = "ru-central1-b"
  allow_stopping_for_update = true
  platform_id               = "standard-v3"

  resources {
    cores  = 2
    memory = 4
    core_fraction = 20
  }

  boot_disk {
    disk_id     = "${yandex_compute_disk.disk-elastic.id}"
    }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private.id
	dns_record {
      fqdn = "elastic.srv."
    ttl = 300
    }
    security_group_ids = [yandex_vpc_security_group.internal.id]
    ip_address         = "10.3.3.4"
  }

  metadata = {
    user-data = "${file("./cloud-init.yml")}"
  }

  scheduling_policy {  
    preemptible = true
  }
}

 
# kibana
resource "yandex_compute_instance" "kibana" {
  name                      = "vm-kibana"
  hostname                  = "kibana"
  zone                      = "ru-central1-b"
  allow_stopping_for_update = true
  platform_id               = "standard-v3"

  resources {
    cores  = 2
    memory = 2
    core_fraction = 20
  }

  boot_disk {
    disk_id     = "${yandex_compute_disk.disk-kibana.id}"
    }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public.id
	dns_record {
      fqdn = "kibana.srv."
    ttl = 300
    }
    nat                = true
    security_group_ids = [yandex_vpc_security_group.internal.id, yandex_vpc_security_group.public-kibana.id]
    ip_address         = "10.4.4.3"
  }

  metadata = {
    user-data = "${file("./cloud-init.yml")}"
  }

  scheduling_policy {  
    preemptible = true
  }
}

resource "local_file" "inventory" {
  content  = <<-XYZ
  [all:vars]
  ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -q user@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"'
  ansible_user=user

  [web]
  web-1 ansible_host=${yandex_compute_instance.web-1.fqdn}
  web-2 ansible_host=${yandex_compute_instance.web-2.fqdn}

  [monitoring]
  zabbix_srv ansible_host=${yandex_compute_instance.zabbix.fqdn}

  [log]
  elastic_srv ansible_host=${yandex_compute_instance.elastic.fqdn}
  kibana_srv  ansible_host=${yandex_compute_instance.kibana.fqdn}
  XYZ
  
  filename = "../ansible/hosts.ini"
}

  
  # ansible_become_pass= "{{ become_password }}"