# Example Sinatra App Deployinator

## The goal

Deploy a simple sinatra app in a secure environment on port 80 using config/infra as code whilst making a bucketload of assumptions.

**Warning:** this is not for production and is a guide only. Here be dragons.

## Requirements

* Hashicorp's Terraform - https://www.terraform.io/downloads.html (tested with 0.11.10)
* Ansible (2.5.0 or above)
* AWS Account (with keys in ENV vars or `~/.aws/credentials`), with the ability to create public VPCs and EC2 instances
* SSH keys to be used for accessing the infrastructure at `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub`

## Just deploy it already (TL;DR)

We recommend reading the rest of this guide first.
But for those who which to jump straight in the lake without looking:

1. Clone this repo and `cd` into this directory
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

## Infrastructure Design

### General Assumptions

There have been many assumptions made as part of this design, including:

* Greenfields deployment (Zero other apps or infrastucture already in use)
* This is only app that will ever be deployed in this specfic AWS VPC
* The app should be built and run exactly as prescribed (E.g.: no switching to unicorn etc.)
* Keep costs low despite use of AWS (potentially using free-tier)
* Someone will have to be able to deploy app updates on an on-going basis

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

*Why?*

* No other OS's having to be supported currently (see General Assumptions)
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

*Is this right for everyone?*

No.

* Limited amount of pre-packaged software
* Not as well supported on various infrastructure (e.g.: no AWS EC2 t3 and m5a type instances)
* You like spending lots of time and effort securing down every last package and their distro defaults

*Security*

As above, the default security setup on Clear Linux is excellent. Minor modification has been made to the SSH config to restrict root logins and password based auth (despite no user on the system having any password by default).

Many other items that you would normally configure in a mainstream linux distro are pre-configured, including:
* NTP time sync (UTC)
* Fail2ban equivalent (Tallow)
* Removal of unneeded software to reduce attack surface (including even cli tools like vi/vim)

The firewall on the server has not been configured due to duplication with the security group which is already restricting access on all public and private networks. This should be configured in production environment.


*Software Bundles*

The following bundles are installed on top of the default AWS image

* git
* containers-basic (Docker)
* python3-basic (for Ansible)
* cryptography (until https://github.com/clearlinux/distribution/issues/272 is fixed upstream)

#### Docker

Technically, using docker and containers isn't really required. We've chosen to use docker containers since it is assumed that there will be future app updates, and the container portability will make app development/deployment/CI/CD significantly easier.

The other option on this OS would be [Kata Containers](https://katacontainers.io/) for extra security, but is not implemented here.

Each container is wrapped in a SystemD service with specified dependencies. This is to simply this demo, but also works in production for _small_ applications. It also allows for logs to be in journald for easy access and rotation and to be managed like any other service.

A larger install would preferably use service discovery (like [Consul](https://www.consul.io)) instead of hardcoded references as well as a multiple instance orchestrator like Kubernetes (available on Clear Linux), Nomad or Unit.

#### Load balancer

Nginx using the latest [public docker image](https://hub.docker.com/_/nginx/).

Configured for security and performance, but without HTTPS/TLS of any kind (*DO NOT DO THIS IN PRODUCTION - EVER!*).

The example sinatra app has no variablilty and so would be a perfect candidate for implementing caching at the nginx level. We've assumed that this won't always be the case and have not included a cache at this time.

#### App servers

Dual app servers allowing for higher availability and easier maintenance without downtime.

Built using a recent version of the public core [ruby docker image](https://hub.docker.com/_/ruby/). Alpine edition for minial size and faster deployment.

## Deployment

The deployment of the Infrastructure, Host OS configuration and App are all scripted using Bash, Terraform and Ansible. All of these scripts are automatable using CI/CD systems like Jenkins or ConcourseCI.

### Host OS

An ideal deployment process would have the infrastructure deployed immutably. E.g.: Packer to build the AMI pre-configured.

We've compromised in this scenario for simplification, and deployed with the default Clear Linux AMI, and post-configured using a minimal amount of Ansible. This lead to the requirement for Python to be installed in the Host OS, which is not otherwise required. Other tools like Puppet do not currently support Clear Linux.

The infra and host build process can be

Build:
```
./build-infra.sh
```

Destroy:
```
./destroy.sh
```

### App Build and Deploy

Preferably the Build process for the App would be handled in CI/CD and then stored in a container or artifact registry. A container vulnerability scanner like [Clair](https://github.com/coreos/clair) should also be implemented.

For simplification in this demo, we've merged the Build and Deploy processes to have the container build happen on the Host OS instead.

The script uses Ansible to complete the App build then deploy via SystemD services automatically. You should trigger this script (which is idempotent) for each app or container change.

Build and Deploy:
```
./build-app-and-deploy.sh
```