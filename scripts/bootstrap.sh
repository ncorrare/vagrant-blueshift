#!/bin/bash
#Run the Puppet agent first, to ensure everything is 'as desired'
/opt/puppetlabs/bin/puppet agent -t
# Because it's difficult to trigger code-manager directly without a LOT of
# work dealing with rbac, just do the work code-manager would do if
# triggered. This can be replaced if CODEMGMT-697 is fixed. Start by running
# r10k to extract the environment to code-staging.
sudo -u pe-puppet bash -c \
        '/opt/puppetlabs/bin/r10k deploy environment \
         -c /opt/puppetlabs/server/data/code-manager/r10k.yaml \
         -pv'

# Perform two calls to file-sync. First, commit the code from code-staging.
# Second, force a sync/deploy to the code directory. The second step is
# performed explicitly so that we are guaranteed the deploy is finished
# before we take any action that depends on that task being done.
certname=$(puppet config print certname --section agent)
curl -kvs --request POST --header "Content-Type: application/json" \
          --cert "/etc/puppetlabs/puppet/ssl/certs/${certname}.pem" \
          --key "/etc/puppetlabs/puppet/ssl/private_keys/${certname}.pem" \
          --cacert "/etc/puppetlabs/puppet/ssl/certs/ca.pem" \
          --data '{"commit-all": true}' \
          'https://localhost:8140/file-sync/v1/commit' && echo
curl -kvs --request POST --header "Content-Type: application/json" \
          --cert "/etc/puppetlabs/puppet/ssl/certs/${certname}.pem" \
          --key "/etc/puppetlabs/puppet/ssl/private_keys/${certname}.pem" \
          --cacert "/etc/puppetlabs/puppet/ssl/certs/ca.pem" \
          'https://localhost:8140/file-sync/v1/force-sync' && echo
curl -ks --request DELETE --header "Content-Type: application/json" \
         --cert "/etc/puppetlabs/puppet/ssl/certs/${certname}.pem" \
         --key "/etc/puppetlabs/puppet/ssl/private_keys/${certname}.pem" \
         --cacert "/etc/puppetlabs/puppet/ssl/certs/ca.pem" \
          'https://localhost:8140/puppet-admin-api/v1/environment-cache'
# Refresh classes in the NC
PATH="/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:/opt/puppet/bin:$PATH"

declare -x PE_CERT=$(puppet agent --configprint hostcert)
declare -x PE_KEY=$(puppet agent --configprint hostprivkey)
declare -x PE_CA=$(puppet agent --configprint localcacert)

declare -x NC_CURL_OPT="-s --cacert $PE_CA --cert $PE_CERT --key $PE_KEY --insecure"

curl -X POST -H 'Content-Type: application/json' $NC_CURL_OPT --insecure https://localhost:4433/classifier-api/v1/update-classes
#Poke firewall holes
/bin/firewall-cmd --zone=public --add-service=https
/bin/firewall-cmd --zone=public --add-service=https --permanent
/bin/firewall-cmd --zone=public --add-service=http
/bin/firewall-cmd --zone=public --add-service=http --permanent
/bin/firewall-cmd --zone=public --add-port=61613/tcp
/bin/firewall-cmd --zone=public --add-port=61613/tcp --permanent
/bin/firewall-cmd --zone=public --add-port=8140/tcp
/bin/firewall-cmd --zone=public --add-port=8140/tcp --permanent
/bin/firewall-cmd --zone=public --add-port=8142/tcp
/bin/firewall-cmd --zone=public --add-port=8142/tcp --permanent
