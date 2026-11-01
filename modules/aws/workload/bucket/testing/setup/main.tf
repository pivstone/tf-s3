terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "4.6.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

resource "docker_image" "ministack" {
  name         = "ministackorg/ministack"
  force_remove = false
  keep_locally = true
}

resource "docker_container" "ministack" {
  image        = docker_image.ministack.image_id
  name         = "tf-s3-bucket-tests"
  wait         = true
  wait_timeout = 60

  healthcheck {
    test     = ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:4566/_ministack/health')"]
    interval = "1s"
    timeout  = "2s"
    retries  = 30
  }

  ports {
    internal = 4566
    external = 4566
  }
}

