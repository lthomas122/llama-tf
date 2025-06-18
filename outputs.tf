output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.app_server.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.app_server.public_ip
}

output "vllm_endpoint" {
  description = "Public vLLM Endpoint"
  value       = "${aws_instance.app_server.public_ip}:8080/v1"
}
