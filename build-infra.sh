#!/bin/bash
#
# Build the Infrastructure and OS Host for Sinatra App
#

# Check for prerequisites
if ! command -v terraform;
then
  echo "Error: please ensure 'terraform' is installed and in your \$PATH";
  exit 1;
fi
if ! command -v ansible-playbook;
then
  echo "Error: please ensure 'ansible-playbook' is installed and in your \$PATH";
  exit 1;
fi

# Gather required data
ssh_from_public_ip_cidr="$(curl https://api.ipify.org 2>/dev/null)/32";
ssh_public_key="$(cat ~/.ssh/id_rsa.pub)";

# Set up terraform
terraform init;

# Build infrastructure in AWS
terraform plan \
 -out sinatra.tfplan \
 -var ssh_public_key="$ssh_public_key" \
 -var ssh_from_public_ip_cidr="$ssh_from_public_ip_cidr";

terraform apply sinatra.tfplan;

# Prepare for app setup
instance="$(terraform output instance_ip)";
echo -e "[all]\\nweb ansible_host=$instance ansible_user=clear" > ansible.inventory;

echo "waiting for auto updates to complete"
sleep 60;

# Add packages and reboot
ssh clear@"$instance" "sudo swupd bundle-add git containers-basic python3-basic cryptography";
ssh clear@"$instance" "sudo reboot";

echo "waiting on reboot to finish";
sleep 30;

# Apply host configuration changes for application and security
export ANSIBLE_HOST_KEY_CHECKING=False;
ansible-playbook -i "$(pwd)/ansible.inventory" --private-key="$HOME/.ssh/id_rsa" --extra-vars "host=all" "$(pwd)/host-config.yml";
echo "instance: $instance";
