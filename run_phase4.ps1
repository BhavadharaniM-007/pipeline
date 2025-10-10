# Change to project directory
cd "C:\Users\BHAVADHARANIM\Documents\phase4"

Write-Host "🚀 Running Terraform Init and Apply..."
terraform init
terraform apply -auto-approve

# Get the EC2 public IP from Terraform output
$public_ip = terraform output -raw web_server_public_ip
Write-Host "✅ EC2 Public IP fetched: $public_ip"

# Create Ansible inventory
$inventoryContent = @"
[web]
ec2-user@$public_ip ansible_ssh_private_key_file=~/.ssh/id_rsa ansible_user=ec2-user
"@

$inventoryPath = ".\ansible\inventories\hosts"
$inventoryContent | Out-File -FilePath $inventoryPath -Encoding ASCII
Write-Host "📁 Ansible inventory created at $inventoryPath"

# Optional: wait for EC2 to be fully up and ready for SSH
Start-Sleep -Seconds 30

# Run Ansible playbook
Write-Host "🧪 Running Ansible Playbook..."
ansible-playbook -i $inventoryPath .\ansible\playbooks\deploy.yml | Tee-Object -FilePath .\deploy_log.txt

Write-Host "✅ Deployment finished. Log saved to deploy_log.txt"
