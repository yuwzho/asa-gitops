terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.7.0"
    }
  }

  # Update this block with the location of your terraform state file
  backend "azurerm" {
    resource_group_name  = "ASA-E-GitOps-State"
    storage_account_name = "asaegitopstfstate"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
    use_oidc             = true
  }
}

provider "azurerm" {
  features {}
  use_oidc = true
}

# Define any Azure resources to be created here. A simple resource group is shown here as a minimal example.
# resource "azurerm_resource_group" "rg-asa" {
#   name     = var.resource_group_name
#   location = var.location
# }

# resource "azurerm_spring_cloud_service" "demo-time-asa" {
#   name                     = "demo-time-asa"
#   resource_group_name      = var.resource_group_name
#   location                 = var.location
#   sku_name                 = "E0"
#   service_registry_enabled = true
#   build_agent_pool_size    = "S1"
#   timeouts {
#   }
# }

# resource "azurerm_spring_cloud_configuration_service" "configservice" {
#   name                    = "default"
#   spring_cloud_service_id = azurerm_spring_cloud_service.demo-time-asa.id
# }

# resource "azurerm_spring_cloud_gateway" "scgateway" {
#   name                    = "default"
#   spring_cloud_service_id = azurerm_spring_cloud_service.demo-time-asa.id
#   instance_count          = 2
# }

# resource "azurerm_spring_cloud_api_portal" "apiportal" {
#   name                          = "default"
#   spring_cloud_service_id       = azurerm_spring_cloud_service.demo-time-asa.id
#   gateway_ids                   = [azurerm_spring_cloud_gateway.scgateway.id]
#   https_only_enabled            = false
#   public_network_access_enabled = false
#   instance_count                = 1
#   timeouts {
#   }
# }

data "azurerm_spring_cloud_service" "service" {
  name                = var.service_name
  resource_group_name = var.resource_group_name
}

resource "azurerm_spring_cloud_app" "demo-time-app" {
  name                = "demo-time"
  resource_group_name = var.resource_group_name
  service_name        = var.service_name
}

resource "azurerm_spring_cloud_build_deployment" "blue" {
  name                = "blue"
  spring_cloud_app_id = azurerm_spring_cloud_app.demo-time-app.id
  build_result_id     = "<default>"
  instance_count      = 2
  quota {
    cpu    = "2"
    memory = "4Gi"
  }
}

resource "azurerm_spring_cloud_build_deployment" "green" {
  name                = "green"
  spring_cloud_app_id = azurerm_spring_cloud_app.demo-time-app.id
  build_result_id     = "<default>"
  instance_count      = 2
  quota {
    cpu    = "2"
    memory = "4Gi"
  }
}

resource "azurerm_spring_cloud_gateway_route_config" "health_check" {
  name                    = "health_check"
  spring_cloud_gateway_id = format("%s/gateways/default", data.azurerm_spring_cloud_service.service.id)
  spring_cloud_app_id     = azurerm_spring_cloud_app.demo-time-app.id
  protocol                = "HTTP"
  route {
    description            = "Retrieve a health check from our application"
    filters                = ["StripPrefix=2", "RateLimit=1,1s"]
    predicates             = ["Path=/test/api/healthcheck", "Method=GET"]
    title                  = "Test API"
    token_relay            = false
    classification_tags    = ["health_check"]
  }
}
