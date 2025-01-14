#!/bin/bash

docker network inspect jenkins >/dev/null 2>&1 || \
docker network create jenkins
docker run \
  --name jenkins-docker \
  --rm \
  --detach \
  --privileged \
  --network jenkins \
  --network-alias docker \
  --env DOCKER_TLS_CERTDIR=/certs \
  --volume jenkins-docker-certs:/certs/client \
  --volume jenkins-data:/var/jenkins_home \
  --publish 2376:2376 \
  --publish 3000:3000 \
  --publish 5000:5000 \
  docker:dind \
  --storage-driver overlay2
echo "Waiting for jenkins-docker to initialize..."
sleep 5
echo "Creating Dockerfile and appending instructions..."
rm ./Dockerfile
echo "
FROM jenkins/jenkins:2.426.2-jdk17
USER root
RUN apt-get update && apt-get install -y lsb-release
RUN curl -fsSLo /usr/share/keyrings/docker-archive-keyring.asc \\
  https://download.docker.com/linux/debian/gpg
RUN echo \"deb [arch=\$(dpkg --print-architecture) \\
  signed-by=/usr/share/keyrings/docker-archive-keyring.asc] \\
  https://download.docker.com/linux/debian \\
  \$(lsb_release -cs) stable\" > /etc/apt/sources.list.d/docker.list
RUN apt-get update && apt-get install -y docker-ce-cli
USER jenkins
RUN jenkins-plugin-cli --plugins \"blueocean:1.27.9 docker-workflow:572.v950f58993843\"
" > Dockerfile
sleep 2
echo "Creating Jenkins Blue Ocean image..."
docker build -t myjenkins-blueocean:2.426.2-1 .
docker run \
  --name jenkins-blueocean \
  --rm \
  --detach \
  --network jenkins \
  --env DOCKER_HOST=tcp://docker:2376 \
  --env DOCKER_CERT_PATH=/certs/client \
  --env DOCKER_TLS_VERIFY=1 \
  --publish 49000:8080 \
  --publish 50000:50000 \
  --volume jenkins-data:/var/jenkins_home \
  --volume jenkins-docker-certs:/certs/client:ro \
  myjenkins-blueocean:2.426.2-1
echo "Waiting for jenkins-blueocean to initialize..."
sleep 120
echo "Creating and appending NGINX configuration..."
rm ./nginx.conf
echo "worker_processes auto;

events {
    worker_connections 1024;
}

http {
    server {
        listen 9000;
        server_name localhost;

        location / {
            proxy_pass http://jenkins-blueocean:8080;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
" > nginx.conf
docker run --name nginx-reverse-proxy \
  --rm \
  --detach \
  --network jenkins \
  --publish 9000:9000 \
  --volume $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro \
  nginx
echo "NGINX reverse proxy is running on http://localhost:9000"
echo "Creating and appending Prometheus configuration..."
rm -rf ./prometheus
mkdir ./prometheus
echo "global:
  scrape_interval: 10s
  evaluation_interval: 10s
scrape_configs:
  - job_name: \"prometheus\"
    static_configs:
      - targets: [\"localhost:9090\"]
  - job_name: \"jenkins\"
    metrics_path: /prom
    static_configs:
      - targets: [\"jenkins-blueocean:8080\"]
" > ./prom/prometheus.yml
docker run --name prometheus-jenkins \
    --rm \
    --detach \
    --network jenkins \
    --publish 9091:9090 \
    --volume $(pwd)/prometheus:/etc/prometheus \
    prom/prometheus
echo "Waiting for prometheus-jenkins to initialize..."
sleep 5
echo "Prometheus is running on http://localhost:9091"
docker volume inspect grafana-storage >/dev/null 2>&1 || \
docker volume create grafana-storage
docker volume inspect grafana-storage
rm -rf ./grafana
mkdir ./grafana
docker run --name grafana-prom \
    --rm \
    --detach \
    --publish 3031:3030 \
    --network jenkins \
    --env "GF_SERVER_HTTP_PORT=3030" \
    grafana/grafana-enterprise
echo "Waiting for grafana to initialize..."
sleep 5
echo "Grafana is running on http://localhost:3031"
# pull prometheus from http://prometheus-jenkins:9090 to grafana