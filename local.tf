locals{
    owners = "ME"
    environment = "dev"
    resource_name_prefix = "testy"
    common_tag ={
        owners = local.owners
        environemnt = local.environment
    }
}