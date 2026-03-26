#!/bin/bash
echo "Cleaning up AWS resources..."

# Delete key pair
aws ec2 delete-key-pair --key-name voip-lab-key --region us-east-1 2>/dev/null
echo "✅ Deleted key pair"

# Clean local state
rm -f terraform.tfstate terraform.tfstate.backup
echo "✅ Cleaned Terraform state"

echo ""
echo "Ready to run: terraform apply"
