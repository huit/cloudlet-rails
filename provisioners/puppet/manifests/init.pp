node default {
  include stdlib

  # parameter defaults
  $default_database_host     = 'localhost'
  $default_database_port     = '3306'
  $default_database_name     = 'railsapp'
  $default_database_user     = 'railsapp'
  $default_database_password = 'railsapp'
  $default_application_port  = '8080'
  $default_application_name  = 'railsapp'
  $default_application_user  = 'rails'
  $default_application_group = 'rails'
  $default_ruby_version      = 'ruby-2.0.0-p247'
  $default_passenger_version = '4.0.20'
  $default_smtp_endpoint     = 'localhost'
  $default_smtp_port         = '25'
  # $default_smtp_domain       = $::domain
  $default_smtp_domain       = 'devel.huit.harvard.edu'

  # parameters passed from nepho
  $nepho_instance_role     = hiera('NEPHO_INSTANCE_ROLE')
  $nepho_external_hostname = hiera('NEPHO_EXTERNAL_HOSTNAME',$::ec2_public_hostname)
  $nepho_backend_hostname  = hiera('NEPHO_BACKEND_HOSTNAME','localhost')
  $nepho_application_name  = hiera('NEPHO_APPLICATION_NAME',$default_application_name)
  $nepho_application_user  = hiera('NEPHO_APPLICATION_USER',$default_application_user)
  $nepho_application_group = hiera('NEPHO_APPLICATION_GROUP',$default_application_group)
  $nepho_ruby_version      = hiera('NEPHO_RUBY_VERSION',$default_ruby_version)
  $nepho_passenger_version = hiera('NEPHO_PASSENGER_VERSION',$default_passenger_version)
  $nepho_database_host     = hiera('NEPHO_DATABASE_HOST',$default_database_host)
  $nepho_database_port     = hiera('NEPHO_DATABASE_PORT',$default_database_port)
  $nepho_database_name     = hiera('NEPHO_DATABASE_NAME',$default_database_name)
  $nepho_database_user     = hiera('NEPHO_DATABASE_USER',$default_database_user)
  $nepho_database_password = hiera('NEPHO_DATABASE_PASSWORD',$default_database_password)
  $nepho_s3_bucket         = hiera('NEPHO_S3_BUCKET',false)
  $nepho_s3_access_key     = hiera('NEPHO_S3_BUCKET_ACCESS','no_s3_bucket_access_provided')
  $nepho_s3_secret_key     = hiera('NEPHO_S3_BUCKET_KEY','no_s3_bucket_secret_provided')
  $nepho_ses_smtp          = str2bool(hiera('NEPHO_SES_SMTP','false'))
  $nepho_ses_smtp_endpoint = hiera('NEPHO_SES_SMTP_ENDPOINT',$default_smtp_endpoint)
  $nepho_ses_smtp_port     = hiera('NEPHO_SES_SMTP_PORT',$default_smtp_port)
  $nepho_ses_smtp_username = hiera('NEPHO_SES_SMTP_USER',false)
  $nepho_ses_smtp_password = hiera('NEPHO_SES_SMTP_PASSWORD',false)
  $nepho_ses_smtp_domain   = hiera('NEPHO_SES_SMTP_DOMAIN',$default_smtp_domain)

  $probe_interval     = "30s"
  $probe_timeout      = "10s"
  $probe_window       = "5"
  $purge_ips          = [  ]

  if $nepho_ses_smtp {
    class { 'postfix':
      smtp_relay     => false,
      tls            => true,
      tls_bundle     => '/etc/ssl/certs/ca-bundle.crt',
      tls_package    => 'ca-certificates',
      mydomain       => $nepho_ses_smtp_domain,
      relay_host     => $nepho_ses_smtp_endpoint,
      relay_port     => $nepho_ses_smtp_port,
      relay_username => $nepho_ses_smtp_username,
      relay_password => $nepho_ses_smtp_password,
      before         => Class['nepho_railsapp'],
    }
  }

  if $nepho_instance_role {
    package { 'update-motd':
      ensure => 'present',
    }

    file { '/etc/update-motd.d/90-motd-role':
      ensure  => 'present',
      owner   => 'root',
      group   => 'root',
      mode    => 0755,
      content => inline_template(file('/tmp/cloudlet-rails/provisioners/puppet/templates/motd-role.erb')),
      require   => Package['update-motd'],
      before    => Exec['run-update-motd'],
      notify    => Exec['run-update-motd'],
    }

    exec { 'run-update-motd':
      path        => '/bin:/sbin:/usr/bin:/usr/sbin',
      command     => 'update-motd',
      logoutput   => 'on_failure',
      refreshonly => true,
    }
  }

  case $nepho_instance_role {
    'varnish': {
      # tier 1
      class { 'varnish':
      }
    }
    'railsapp': {
      # tier 2
      class { 'nepho_railsapp':
        app_name          => $nepho_application_name,
        server_name       => $nepho_external_hostname,
        db_server         => $nepho_database_host,
        db_root_user      => $nepho_database_user,
        db_root_password  => $nepho_database_password,
        db_name           => $nepho_database_name,
        db_user           => $nepho_database_user,
        db_password       => $nepho_database_password,
        db_port           => $nepho_database_port,
        app_port          => $default_application_port,
        app_user          => $nepho_application_user,
        app_group         => $nepho_application_group,
        ruby_version      => $nepho_ruby_version,
        passenger_version => $nepho_passenger_version,
        admin_email       => "${nepho_application_name}@${nepho_ses_smtp_domain}",
        s3_bucket         => false, # disable for PoC
        s3_access_key     => $nepho_s3_access_key,
        s3_secret_key     => $nepho_s3_secret_key,
      }
    }
    default: {
      # standalone
      #class { 'varnish': }
      class { 'nepho_railsapp':
        app_name          => $nepho_application_name,
        server_name       => $nepho_external_hostname,
        db_server         => $nepho_database_host,
        db_root_user      => 'root',
        db_root_password  => $nepho_database_password,
        db_name           => $nepho_database_name,
        db_user           => $nepho_database_user,
        db_password       => $nepho_database_password,
        db_port           => $nepho_database_port,
        app_port          => $default_application_port,
        app_user          => $nepho_application_user,
        app_group         => $nepho_application_group,
        ruby_version      => $nepho_ruby_version,
        passenger_version => $nepho_passenger_version,
        admin_email       => "${nepho_application_name}@${nepho_ses_smtp_domain}",
      }
    }
  }
}

class nepho_railsapp (
  $app_name,
  $server_name,
  $db_server,
  $db_root_user,
  $db_root_password,
  $db_name,
  $db_user,
  $db_password,
  $db_port,
  $app_port,
  $app_user,
  $app_group,
  $ruby_version,
  $passenger_version,
  $admin_email = 'admin@example.com',
  $s3_bucket = false,
  $s3_access_key = false,
  $s3_secret_key = false,
  $ensure = 'present'
) {
  class { 'railsapp':
    appname          => $nepho_railsapp::app_name,
    servername       => $nepho_railsapp::server_name,
    railsuser        => $nepho_railsapp::app_user,
    railsgroup       => $nepho_railsapp::app_group,
    rubyversion      => $nepho_railsapp::ruby_version,
    passengerversion => $nepho_railsapp::passenger_version,
  }

  $deployment_gems = [ 'bundler', 'capistrano', 'rvm-capistrano', ]

  include rvm
  rvm_gem { $nepho_railsapp::deployment_gems:
    ensure       => 'latest',
    ruby_version => $nepho_railsapp::ruby_version,
    require      => Class['railsapp'],
  }

  augeas { "ec2-user_${nepho_railsapp::app_group}_group":
    context => '/files/etc/group',
    changes => "set ${nepho_railsapp::app_group}/user[00] ec2-user",
    onlyif  => "match ${nepho_railsapp::app_group}/user[. = \"ec2-user\"] size == 0",
    incl    => '/etc/group',
    lens    => 'Group.lns',
    require => Class['railsapp'],
  }

  augeas { "apache_${nepho_railsapp::app_group}_group":
    context => '/files/etc/group',
    changes => "set ${nepho_railsapp::app_group}/user[00] apache",
    onlyif  => "match ${nepho_railsapp::app_group}/user[. = \"apache\"] size == 0",
    incl    => '/etc/group',
    lens    => 'Group.lns',
    require => Class['railsapp'],
  }
}
