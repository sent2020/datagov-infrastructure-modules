output "db_name" {
  value = module.db.db_name
}

output "db_password" {
  value     = var.db_password
  sensitive = true
}

output "db_server" {
  value = module.db.db_server
}

output "db_username" {
  value = module.db.db_username
}

output "lb" {
  value = module.web.web_lb_dns
}

