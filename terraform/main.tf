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
  region = "nyc2"
}

# Create the necessary number of blue droplets
resource "digitalocean_droplet" "blue" {
  count    = var.number_of_instances
  image    = "ubuntu-20-04-x64"
  name     = "elixir-api-blue-${count.index}"
  region   = local.region
  size     = "s-1vcpu-1gb"
  ssh_keys = [var.ssh_key_id]
  graceful_shutdown = true

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

#  TODO: Is there a way to run this resource according to the active color var?
resource "digitalocean_droplet" "green" {
  count    = var.number_of_instances
  image    = "ubuntu-20-04-x64"
  name     = "elixir-api-green-${count.index}"
  region   = local.region
  size     = "s-1vcpu-1gb"
  ssh_keys = [var.ssh_key_id]
  graceful_shutdown = true

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

# Health check
resource "null_resource" "health_check" {
  depends_on = [digitalocean_droplet.blue, digitalocean_droplet.green]

  provisioner "local-exec" {
    command = <<EOT
      echo "Checking health of the new instances"

      DROPLETS=$(doctl compute droplet list --format ID,PublicIPv4 | grep "elixir-api-${var.active_color}" | awk '{print $1}')

      for i in {1..10}; do
        for droplet_ip in $DROPLETS; do
          if curl -sSf http://$droplet_ip:4000/api/hello | grep "Hello"; then
            echo "Instance $droplet_ip is healthy."
          else
            echo "Instance $droplet_ip failed health check. Retrying..."
            sleep 5
            continue
          fi
        done

        echo "All instances are healthy."
        exit 0
      done

      echo "Health check failed after 10 attempts"
      
      terraform apply -var="active_color=${local.inactive_color}" --auto-approve

      exit 1
    EOT

  }
}

# Load balancer that points to the new instances after they pass in the health check
resource "digitalocean_loadbalancer" "api_lb" {
  depends_on = [null_resource.health_check]

  name   = "api-lb"
  region = local.region


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
    check_interval_seconds = 3
    response_timeout_seconds = 3
    unhealthy_threshold = 2
    healthy_threshold = 2
  }

  droplet_ids = concat(
    digitalocean_droplet.blue[*].id,
    digitalocean_droplet.green[*].id
  )
}

# Wait for the load balancer to distribute traffic
resource "null_resource" "wait_for_balancing" {
  depends_on = [digitalocean_loadbalancer.api_lb]

  triggers = {
    color = var.active_color
  }

  provisioner "local-exec" {
    command = <<EOT
      echo "Waiting for the load balancer to distribute traffic..."

      sleep 10
    EOT
  }
}

# Destroy the old instances
resource "null_resource" "destroy_old_instances" {
  depends_on = [null_resource.wait_for_balancing]

  triggers = {
    color = var.active_color
  }

  provisioner "local-exec" {
    command = <<EOT
      OLD_DROPLETS=$(doctl compute droplet list --format ID,Name | grep "elixir-api-${local.inactive_color}" | awk '{print $1}' | paste -sd "," -)
      
      if [ ! -z "$OLD_DROPLETS" ]; then
        echo "Draining old instances before destroying them..."

        # for droplet_id in $(echo $OLD_DROPLETS | tr "," "\n"); do
        #   doctl compute droplet-action shutdown $droplet_id

        #   echo "Instance $droplet_id is being drained..."

        #   sleep 10

        #   doctl compute droplet-action power-off $droplet_id

        #   echo "Instance $droplet_id is powered off."
        # done

        # doctl compute load-balancer remove-droplets ${digitalocean_loadbalancer.api_lb.id} --droplet-ids $OLD_DROPLETS

        # echo "Waiting 30 seconds to drain the old instances..."
        # sleep 30

        echo "Destroying old instances..."

        for droplet_id in $(echo $OLD_DROPLETS | tr "," "\n"); do
          doctl compute droplet delete -f $droplet_id
        done

        echo "Old instances removed successfully."
      else
        echo "No old instances found."
      fi
    EOT
  }
}

output "droplet_ips" {
  value = var.active_color == "blue" ? digitalocean_droplet.blue[*].ipv4_address : digitalocean_droplet.green[*].ipv4_address
}
