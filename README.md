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

## Design

### General Assumptions

There have been many assumptions made as part of this design, including:

* Greenfields deployment (Zero other apps or infrastucture already in use)
* This is only app that will ever be deployed in this specfic AWS VPC
* The app should be built and run exactly as prescribed (E.g.: no switching to unicorn etc.)
* Keep costs low despite use of AWS (potentially using free-tier)

### Overview

```
AWS VPC
+----------------------------------------+
|  AWS EC2 Instance                      |
|  +----------------------------------+  |
|  |  Docker                          |  |
|  |  +----------------------------+  |  |
|  |  |  +----------------------+  |  |  |
|  |  |  |    Load Balancer     |  |  |  |
|  |  |  +----------------------+  |  |  |
|  |  |       |            |       |  |  |
|  |  |  +---------+  +---------+  |  |  |
|  |  |  |  App 1  |  |  App 2  |  |  |  |
|  |  |  +---------+  +---------+  |  |  |
|  |  +----------------------------+  |  |
|  +----------------------------------+  |
+----------------------------------------+
```

#### AWS

This project deploys to AWS to fully show how this can be configured with infra as code.

Hashicorp's Terraform is ideal for this purpose as it's cross platform and highly supported.

The setup is for a VPC with a single public subnet for easier demonstration purposes.

IPv4 and IPv6 are both enabled privately and publically.

The security group restricts the EC2 instance access exactly the same for both private and public access. This would not necessarily be the case for a normal deployment, particularly for private subnet access.

* Inbound
  * TCP 80
  * TCP 22 (restricted to a single public IP, and the subnet private addresses)
* Outbound
  * All traffic

#### AWS EC2 Instance

The instance is a single t2.micro due to it's availability everywhere and minial load during this demo.

In a production environment, there would likely need to be multiple instances to allow higher availability and to also potentially support other apps on the same infrastructure.

The host operating system is [Intel's Clear Linux](https://clearlinux.org).

**Why?**

* No other OS's having to be supported being used (see General Assumptions)
* Keeps ongoing maintenance to a minimum
* Super fast performance
* Excellent baseline [security](https://clearlinux.org/documentation/clear-linux/concepts/security) with:
  * Really minimal installed software
  * Fast security updates, with constant vulnerability scanning
  * Close to latest version of every software package
  * Secure and sane default configurations
  * Tallow configured by default (fail2ban equivalent)
* Simple and fast updates with deltas (including auto update if required)
* Backed by Intel

**Is this right for everyone?**

No.

* Limited amount of pre-packaged software
* Not as well supported on various infrastructure (e.g.: no AWS EC2 t3 and m5a type instances)
* You like spending lots of time and effort securing down every last package and their distro defaults

