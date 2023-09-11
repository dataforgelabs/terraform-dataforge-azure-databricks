output "workspace_url" {
    value = module.databricks_workspace.workspace_url
    description = "URL used to login and access the Databricks workspace. For first time login, use the root Databricks account user that was used for the Terraform run"
}