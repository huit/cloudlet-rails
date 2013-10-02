#!/bin/sh

function run_if_x {
  [[ -z "$1" ]] && return
  [[ -x "$1" ]] && "$1"
  return
}

## Enable Puppet Labs repo

# Fake a redhat-release
[ -r /etc/redhat-release ] || echo "CentOS release 6.4 (Final)" > /etc/redhat-release

# Get the Puppet Labs repo installed
rpm -ivh http://yum.puppetlabs.com/el/6/products/i386/puppetlabs-release-6-7.noarch.rpm ||
  echo "Unable to install Puppet Labs repo: exit code $?"

# Get EPEL installed
EPEL_RPM=http://mirror.utexas.edu/epel/6/i386/epel-release-6-8.noarch.rpm
if ! [ -f /etc/yum.repos.d/epel.repo ]; then
  rpm -ivh ${EPEL_RPM} || /bin/true
fi

## Install Puppet and dependencies

REQUIRED_PKGS="puppet augeas redhat-lsb git curl wget s3cmd aws-cli ruby-devel rubygems gcc"

export PATH="${PATH}:/usr/local/bin"
PKGS="${REQUIRED_PKGS} ${extra_pkgs}"
yum -y --enablerepo=epel --disableplugin=priorities update ${PKGS}

# Install r10k
puppet resource package=r10k provider=gem ensure=present ||
  echo "Unable to install r10k gem: exit code $?"

# Deploy r10k modules
if [ -r 'provisioners/puppet/Puppetfile' ]; then
  pushd provisioners/puppet
  HOME=/root PUPPETFILE_DIR=/etc/puppet/modules r10k puppetfile install
  popd
else
  echo 'No Puppetfile found, skipping r10k'
fi

# Run Puppet bootstrap
run_if_x 'provisioners/puppet/scripts/bootstrap.sh'

# Run Puppet deploy
run_if_x 'provisioners/puppet/scripts/deploy.sh'
