output "rds_address" {
value = aws_db_instance.tp_rds.address
}

output "rds_username" {
value = aws_db_instance.tp_rds.username
}

output "rds_security_group_id" {
value = aws_security_group.tp_rds_sg.id
}
