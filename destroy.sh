#!/bin/bash
#
# Destroy all built infrastructure
#
# "I am the destroyer of worlds"
#
ssh_from_public_ip_cidr="$(curl https://api.ipify.org 2>/dev/null)/32";
ssh_public_key="$(cat ~/.ssh/id_rsa.pub)";
terraform destroy \
 -var ssh_public_key="$ssh_public_key" \
 -var ssh_from_public_ip_cidr="$ssh_from_public_ip_cidr";
