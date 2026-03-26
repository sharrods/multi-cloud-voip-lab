#!/bin/bash
set -e

echo "=== Step 1: Download Exporter Images from GCP ==="
# SSH to GCP and export images, then transfer back
ssh-gcp << 'GCP_EXPORT'
cd /tmp
docker save voiplab_opensips-exporter:latest | gzip > opensips-exporter.tar.gz
docker save voiplab_freeswitch-exporter:latest | gzip > freeswitch-exporter.tar.gz
docker save voiplab_rtpengine-exporter:latest | gzip > rtpengine-exporter.tar.gz
GCP_EXPORT

# Download from GCP to Azure
gcloud compute scp --project=project-3f2b7cc9-5d58-4011-947 --zone=us-central1-c \
  instance-20251206-123934:/tmp/opensips-exporter.tar.gz ~/
gcloud compute scp --project=project-3f2b7cc9-5d58-4011-947 --zone=us-central1-c \
  instance-20251206-123934:/tmp/freeswitch-exporter.tar.gz ~/
gcloud compute scp --project=project-3f2b7cc9-5d58-4011-947 --zone=us-central1-c \
  instance-20251206-123934:/tmp/rtpengine-exporter.tar.gz ~/

echo "✅ Images downloaded to Azure VM"

echo ""
echo "=== Step 2: Transfer to Oracle VM1 ==="
scp -i ~/.ssh/ssh-key-2026-01-01.key ~/opensips-exporter.tar.gz opc@144.24.1.61:~/

echo ""
echo "=== Step 3: Transfer to Oracle VM2 ==="
scp -i ~/.ssh/ssh-key-2026-01-01.key ~/freeswitch-exporter.tar.gz opc@141.148.155.33:~/
scp -i ~/.ssh/ssh-key-2026-01-01.key ~/rtpengine-exporter.tar.gz opc@141.148.155.33:~/

echo ""
echo "=== Step 4: Deploy on Oracle VM1 ==="
ssh -i ~/.ssh/ssh-key-2026-01-01.key opc@144.24.1.61 << 'ORACLE_VM1'
# Start Docker if needed
~/start-docker.sh
sleep 10

# Load image
gunzip -c opensips-exporter.tar.gz | sudo /usr/local/bin/docker load

# Remove old container if exists
sudo /usr/local/bin/docker rm -f opensips-exporter 2>/dev/null || true

# Deploy opensips-exporter (port 9153 exposed)
sudo /usr/local/bin/docker run -d --name opensips-exporter \
  --restart unless-stopped \
  -p 9153:8000 \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  voiplab_opensips-exporter:latest

# Verify
sleep 5
sudo /usr/local/bin/docker ps | grep opensips-exporter
echo "Testing opensips-exporter endpoint:"
curl -s http://localhost:9153/metrics | grep opensips_up || echo "Exporter starting..."
ORACLE_VM1

echo ""
echo "=== Step 5: Deploy on Oracle VM2 ==="
ssh -i ~/.ssh/ssh-key-2026-01-01.key opc@141.148.155.33 << 'ORACLE_VM2'
# Start Docker if needed
~/start-docker.sh
sleep 10

# Load images
gunzip -c freeswitch-exporter.tar.gz | sudo /usr/local/bin/docker load
gunzip -c rtpengine-exporter.tar.gz | sudo /usr/local/bin/docker load

# Remove old containers if exist
sudo /usr/local/bin/docker rm -f freeswitch-exporter 2>/dev/null || true
sudo /usr/local/bin/docker rm -f rtpengine-exporter 2>/dev/null || true

# Deploy freeswitch-exporter (port 9282 exposed)
sudo /usr/local/bin/docker run -d --name freeswitch-exporter \
  --restart unless-stopped \
  -p 9282:8000 \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  voiplab_freeswitch-exporter:latest

# Deploy rtpengine-exporter (port 9092 exposed)
sudo /usr/local/bin/docker run -d --name rtpengine-exporter \
  --restart unless-stopped \
  -p 9092:9092 \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  voiplab_rtpengine-exporter:latest

# Verify
sleep 5
sudo /usr/local/bin/docker ps | grep exporter
echo ""
echo "Testing freeswitch-exporter endpoint:"
curl -s http://localhost:9282/metrics | grep freeswitch_up || echo "Exporter starting..."
echo ""
echo "Testing rtpengine-exporter endpoint:"
curl -s http://localhost:9092/metrics | grep rtpengine_up || echo "Exporter starting..."
ORACLE_VM2

echo ""
echo "=== Cleanup ==="
rm ~/opensips-exporter.tar.gz
rm ~/freeswitch-exporter.tar.gz
rm ~/rtpengine-exporter.tar.gz

echo ""
echo "✅ Deployment Complete!"
echo ""
echo "=== Final Verification ==="
echo "Oracle VM1 - OpenSIPS Exporter (port 9153):"
ssh -i ~/.ssh/ssh-key-2026-01-01.key opc@144.24.1.61 "curl -s http://localhost:9153/metrics | grep -c '^opensips_' || echo '0'"

echo "Oracle VM2 - FreeSWITCH Exporter (port 9282):"
ssh -i ~/.ssh/ssh-key-2026-01-01.key opc@141.148.155.33 "curl -s http://localhost:9282/metrics | grep -c '^freeswitch_' || echo '0'"

echo "Oracle VM2 - RTPEngine Exporter (port 9092):"
ssh -i ~/.ssh/ssh-key-2026-01-01.key opc@141.148.155.33 "curl -s http://localhost:9092/metrics | grep -c '^rtpengine_' || echo '0'"
