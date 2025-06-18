#!/bin/bash

# install docker on the ec2 instance
sudo yum update -y
sudo yum install docker -y

echo DOCKER_INSTALLED

# Create docker user 
sudo usermod -a -G docker ec2-user
id ec2-user
newgrp docker

echo DOCKER_USER_CREATED

# Install docker-compose
sudo yum install python3-pip
pip3 install --user docker-compose

echo DOCKER_COMPOSE_INSTALLED

# Start Docker
sudo systemctl enable docker.service
sudo systemctl start docker.service

echo DOCKER_STARTED

# Check Status
sudo systemctl status docker.service

cd ~
# Create Docker Network
docker network create vllm_nginx
# Start vLLM
docker run -it -d --runtime nvidia --gpus all  --name vllmllama  --network vllm_nginx  -v ~/.cache/huggingface:/root/.cache/huggingface     --env "HUGGING_FACE_HUB_TOKEN=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"     -p 8000:8000     --ipc=host     vllm/vllm-openai:latest     --model meta-llama/Llama-3.2-3B-Instruct --enforce-eager     --max_num_seqs 16  --max-model-len 4096

mkdir nginx_conf

cat <<EOT >> nginx_conf/nginx.conf
worker_processes auto;
events {
    worker_connections 1024;
}

http {
    upstream backend {
        least_conn;
        server vllmllama:8000 max_fails=3 fail_timeout=10000s;
    }
    
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;

        root /usr/share/nginx/html;
        
        location / {
            proxy_pass http://backend;
            proxy_redirect default;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-Host \$host;
            proxy_set_header X-Forwarded-Server \$host;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            add_header Content-Type application/json;
        }
    }
}
EOT

docker run -it -d -p 8080:80 --network vllm_nginx \
-v $(pwd)/nginx_conf/nginx.conf:/etc/nginx/nginx.conf:ro \
--name nginx-lb nginx:latest

docker logs nginx-lb

sudo yum install iptables-services -y
sudo systemctl enable iptables
sudo systemctl start iptables
sudo iptables -I INPUT -p tcp --dport 80 -j LOG
sudo iptables -I INPUT 1 -p tcp -m tcp  --dport 80 -j ACCEPT
sudo iptables -I INPUT 1 -p tcp -m tcp  --dport 8080 -j ACCEPT
service iptables save
