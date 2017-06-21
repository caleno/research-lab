#!/bin/bash
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

pushd "terraform/deployments/$1"

if [ ! -f local.tfvars ]; then
    echo "You must create local.tfvars in the deployment dir" >&2
    popd
    exit 1
fi

terraform get

# This first (serial) run of the security group rules are needed due to strange
# behaviour where only some of the rules are there after the initial run unless
# the are processed sequentially.
#
# See:
#     https://github.com/hashicorp/terraform/issues/7519
#
if [ "$1" != "aws" ]; then
    terraform apply -var-file local.tfvars -parallelism 1 \
              -target module.securitygroups.openstack_networking_secgroup_rule_v2.rule_ssh_access_ipv4 \
              -target module.securitygroups.openstack_networking_secgroup_rule_v2.rule_kube_lb_http_ipv4 \
              -target module.securitygroups.openstack_networking_secgroup_rule_v2.rule_kube_lb_https_ipv4 \
              -target module.securitygroups.openstack_networking_secgroup_rule_v2.rule_kube_master_ipv4
fi

# Now, do the rest in parallell as normal
terraform apply -var-file local.tfvars
terraform output inventory > ../../../ansible/inventory
popd

./ansible/apply.sh
