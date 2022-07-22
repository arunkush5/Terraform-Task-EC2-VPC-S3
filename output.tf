output "bucket" {
  value       = aws_s3_bucket.terra-bucket-arun.id
  description = "Bucket Name"
}

output "ssh_command" {
  value = ["Run this command to connect: ssh -i ~/terra-ec2-instance.pem ubuntu@${aws_instance.Testing_instance.public_ip}"]
}

output "public_ip" {
  value = aws_instance.Testing_instance.public_ip
}