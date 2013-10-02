#!/bin/bash

pushd provisioners/puppet

if [[ -r 'manifests/init.pp' ]]; then
  echo 'Beginning first Puppet run.'
  puppet apply manifests/init.pp
  echo 'Finishing first Puppet run.'

  echo 'Beginning second Puppet run.'
  puppet apply manifests/init.pp
  echo 'Finishing second Puppet run.'
fi

popd
