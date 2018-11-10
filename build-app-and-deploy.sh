#!/bin/bash
#
# Sinatra App Build and Deploy
#
# Uses ansible to build the sinatra app into a container and start using docker
# Warning: Don't do this in production! Build *should* be done in CI/CD then saved to a container/artifact registry first.
#
export ANSIBLE_HOST_KEY_CHECKING=False;
ansible-playbook -i "$(pwd)/ansible.inventory" --private-key="$HOME/.ssh/id_rsa" --extra-vars "host=all" "$(pwd)/build.yml";

echo -e "\\nAPP URL: http://$(terraform output instance_ip)/";
