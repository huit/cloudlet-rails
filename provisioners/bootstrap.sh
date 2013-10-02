#!/bin/bash

function run_if_x {
  [[ -z "$1" ]] && return
  [[ -x "$1" ]] && "$1"
  return
}

# Run Puppet bootstrap
run_if_x './provisioners/puppet/scripts/bootstrap.sh'

# Run Puppet deploy
run_if_x './provisioners/puppet/scripts/deploy.sh'
