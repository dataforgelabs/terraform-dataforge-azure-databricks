output "workspace_url" {
    value = azurerm_databricks_workspace.main.workspace_url
}

output "application_id" {
    value = azuread_service_principal.main.application_id
}

output "id" {
    value = azuread_service_principal.main.id
}

output "client_secret_key" {
    value = databricks_secret.service_principal_key.key
}

output "client_secret_key_string_value" {
    value = databricks_secret.service_principal_key.string_value
}

output "client_secret_key_string_id" {
    value = databricks_secret.service_principal_key.id
}
