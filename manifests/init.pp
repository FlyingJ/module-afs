# == Class: afs
#
# Installs afs packages. Manages the afs service.
#
# === Parameters
#
# [*dynamic_root*]
#   Whether to configure DYNROOT (afs dynamic root). Default is true.
#
# === Variables
#
# None
#
# === Examples
#
# class { 'afs': }
#
# include afs
#
# === Authors
#
# Jason Harrington <jason@fnal.gov>
#
# === Copyright
#
# No copyright expressed, or implied.
#
class afs ($dynamic_root = true) {

  # setting a variable to let others know that we have afs
  $with_afs = true

  # parameter validation
  if ! ("${dynamic_root}" in ['true', 'false']) {
    fail 'Only valid values for dynamic_root are true or false'
  }

  #### BEGIN package management
  package {'openafs-client': ensure => 'installed' }

  if ($::lsbmajdistrelease < 6) {
    package {"kernel-module-openafs-${::kernelrelease}":
      ensure => 'installed',
      before => Package['openafs-client'],
    }
  }
  else {
    package{'kmod-openafs':
      ensure => 'installed',
      before => Package['openafs-client'],
    }
  }

  package {'openafs-krb5':
    ensure  => 'installed',
    require => Package['openafs-client'],
  }

  package {'openafs-compat':
    ensure  => 'installed',
    require => Package['openafs-client'],
  }
  #### END package management

  #### BEGIN configuration management
  # Push out custom augeas lens for modification of /etc/sysconfig/afs
  # NOTE: this is only required for augeas versions < 1.0.0
  # 1.0.0 changes lense behavior to default include, then black list
  # files with their own lenses
  if $::augeasversion < '1.0.0' {
    file {'/usr/share/augeas/lenses/dist/sysconfig_afs.aug':
      ensure  => 'file',
      source  => 'puppet:///modules/afs/usr/share/augeas/lenses/dist/sysconfig_afs.aug',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => Package['augeas'],
    }
  } else {
    file {'/usr/share/augeas/lenses/dist/sysconfig_afs.aug':
      ensure => 'absent',
    }
  }

  augeas {'augeas /etc/sysconfig/afs OPTIONS':
    context => '/files/etc/sysconfig/afs',
    changes => 'set OPTIONS $LARGE',
    onlyif  => 'get OPTIONS != $LARGE',
    notify  => Service['afs'],
    require => [Package['openafs-client'], File['/usr/share/augeas/lenses/dist/sysconfig_afs.aug']],
  }

  if ! $dynamic_root {
    augeas {'augeas /etc/sysconfig/afs ENABLE_DYNROOT':
      context => '/files/etc/sysconfig/afs',
      changes => 'set ENABLE_DYNROOT off',
      onlyif  => 'get ENABLE_DYNROOT != off',
      notify  => Service['afs'],
      require => [Package['openafs-client'], File['/usr/share/augeas/lenses/dist/sysconfig_afs.aug']],
    }
  }
  #### END configuration management

  #### BEGIN service management
  service {'afs':
    ensure     => 'running',
    hasrestart => true,
    enable     => true,
    require    => [Augeas['augeas /etc/sysconfig/afs OPTIONS'], Package['openafs-client'], ],
  }
  #### END service management

}
