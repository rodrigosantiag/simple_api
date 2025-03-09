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

# Set the default active color
variable "active_color" {
  default = "blue"
}

# Compute inactive color
locals {
  inactive_color = var.active_color == "blue" ? "green" : "blue"
}

# Create the necessary number of blue droplets
resource "digitalocean_droplet" "blue" {
  count    = var.number_of_instances
  image    = "ubuntu-20-04-x64"
  name     = "elixir-api-blue-${count.index}"
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

resource "digitalocean_droplet" "green" {
  count    = var.number_of_instances
  image    = "ubuntu-20-04-x64"
  name     = "elixir-api-green-${count.index}"
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

data "digitalocean_droplets" "new_instances" {
  filter {
    key      = "name"
    match_by = "re"
    values   = ["elixir-api-${var.active_color}-*"]
  }
}

data "digitalocean_droplets" "old_instances" {
  filter {
    key      = "name"
    match_by = "re"
    values   = ["elixir-api-${local.inactive_color}-*"]
  }
}

# Load balancer that points to the new instances after they pass in the health check
resource "digitalocean_loadbalancer" "api_lb" {
  name   = "api-lb"
  region = "nyc2"


  forwarding_rule {
    entry_port      = "80"
    entry_protocol  = "http"
    target_port     = "4000"
    target_protocol = "http"
  }

  healthcheck {
    port     = 4000
    protocol = "http"
    path     = "/api/hello"
  }

  droplet_ids = concat(
    digitalocean_droplet.blue[*].id,
    digitalocean_droplet.green[*].id
    )

  depends_on = [
    data.digitalocean_droplets.new_instances
  ]
}

# Destroy the old instances
resource "null_resource" "destroy_old_instances" {
  depends_on = [digitalocean_loadbalancer.api_lb]

  triggers = {
    color = var.active_color
  }

  provisioner "local-exec" {
    command = join("\n", [
      for droplet in data.digitalocean_droplets.old_instances.droplets :
      "doctl compute droplet delete ${droplet.id} --force"
    ])
  }
}

output "droplet_ips" {
  value = data.digitalocean_droplets.new_instances.droplets[*].ipv4_address
}
