output "docker_Server" {
  value = aws_instance.docker-server.public_ip
}
output "jenkins_Server" {
  value = aws_instance.jenkins-master.public_ip
}