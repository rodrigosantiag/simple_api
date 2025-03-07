terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}


# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}

# Set the number of instances to create
variable "number_of_instances" {
  default = 2
}

# Create a web server
# Create a new Web Droplet in the nyc2 region
resource "digitalocean_droplet" "app" {
  count    = var.number_of_instances
  image    = "ubuntu-20-04-x64"
  name     = "elixir-api-${count.index}"
  region   = "nyc2"
  size     = "s-1vcpu-1gb"
  ssh_keys = [var.ssh_key_id]

  connection {
    type        = "ssh"
    user        = "root"
    private_key = var.private_key
    host        = self.ipv4_address
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y docker.io",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo docker login ghcr.io -u ${var.github_username} -p ${var.github_token}",
      "sudo docker pull ghcr.io/rodrigosantiag/simple_api:latest",
      "sudo docker run -e SECRET_KEY_BASE=${var.secret_key_base} -d --name simple_api -p 4000:4000 ghcr.io/rodrigosantiag/simple_api:latest"
    ]
  }
}

resource "digitalocean_loadbalancer" "api_lb" {
  name = "api-lb"
  region = "nyc2"


  forwarding_rule {
    entry_port = "80"
    entry_protocol = "http"
    target_port = "4000"
    target_protocol = "http"
  }

  healthcheck {
    port = 4000
    protocol = "http"
    path = "/api/hello"
  }

  droplet_ids = digitalocean_droplet.app[*].id
}

output "droplet_ips" {
  value = [for droplet in digitalocean_droplet.app : droplet.ipv4_address]
}