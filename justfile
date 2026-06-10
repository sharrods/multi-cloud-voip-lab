
# ============================================================
# GCP <-> Azure sync — multi-cloud-voip-lab
# Run from Azure (azureuser@4.235.114.198)
# GCP static IP: 34.44.206.214 (gcp-voip-static, us-central1)
# ============================================================

gcp_host := "sharrods@34.44.206.214"
gcp_key  := "~/.ssh/google_compute_engine"
gcp_dir  := "~/multi-cloud-voip-lab/gcp"

gcp-branch branch:
    git -C ~/multi-cloud-voip-lab checkout main
    git -C ~/multi-cloud-voip-lab pull
    git -C ~/multi-cloud-voip-lab checkout -b {{branch}}
    @echo "On {{branch}}. Run 'just gcp-sync' to pull the current GCP state as your baseline."

gcp-sync:
    rsync -avz -e "ssh -i {{gcp_key}}" \
        {{gcp_host}}:~/voiplab/opensips/ \
        {{gcp_dir}}/opensips/
    rsync -avz -e "ssh -i {{gcp_key}}" \
        {{gcp_host}}:~/voiplab/docker-compose.yml \
        {{gcp_dir}}/docker-compose.yml
    @echo "GCP -> Azure sync complete. Run 'just gcp-diff' to review changes."

gcp-diff:
    git -C ~/multi-cloud-voip-lab diff -- gcp/

gcp-status: gcp-sync gcp-diff

gcp-save message:
    just gcp-sync
    git -C ~/multi-cloud-voip-lab add gcp/
    git -C ~/multi-cloud-voip-lab commit -m "{{message}}"
    @echo "Committed. Run 'git -C ~/multi-cloud-voip-lab push' when ready."

gcp-deploy:
    rsync -avz -e "ssh -i {{gcp_key}}" \
        {{gcp_dir}}/opensips/ \
        {{gcp_host}}:~/voiplab/opensips/
    ssh -i {{gcp_key}} {{gcp_host}} "docker restart opensips && docker logs --tail 20 opensips"
