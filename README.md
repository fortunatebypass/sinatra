# Example Sinatra App Deployinator

## The goal

Deploy a simple sinatra app in a secure environment on port 80 using config/infra as code whilst making a bucketload of assumptions.

**Warning:** this is not for production and is a guide only. Here be dragons.

## Requirements

* Hashicorp's Terraform - https://www.terraform.io/downloads.html (tested with 0.11.10)
* Ansible (2.5.0 or above)
* AWS Account (with keys in ENV vars or ~/.aws/credentials), with the ability to create public VPCs and EC2 instances
* SSH keys to be used for accessing the infrastructure at ~/.ssh/id_rsa and ~/.ssh/id_rsa.pub

## Just deploy it already (TL;DR)

We recommend reading the rest of this guide first.
But for those who which to jump straight in the lake without looking:

1. Clone this repo and cd into this directory
2. Build the Infrastructure and Host OS (will take a few minutes)
```
./build-infra.sh
```
3. Build and Deploy the App
```
./build-app-and-deploy.sh
```
4. Access the App on HTTP port 80 as described at the end of the deploy
5. Cleanup and wipe all traces (yes at the prompt)
```
./destroy.sh
```