#
# Cookbook Name:: cfncluster
# Recipe:: base_install
#
# Copyright (c) 2015 Amazon Web Services, All Rights Reserved.

# Disable selinux
selinux_state "SELinux Disabled" do
  action :disabled
  only_if 'which getenforce'
end

# Setup directories
directory '/etc/cfncluster'
directory node['cfncluster']['base_dir']
directory node['cfncluster']['sources_dir']

## Being explicit about the included recipes and when they should be run
include_recipe "yum-epel"
include_recipe "build-essential"

# Setup Python (require extra work due to setuptools bug)
include_recipe "python"
python_pip 'setuptools' do
  action :upgrade
  version node.default['python']['setuptools_version']
end

# Install AWSCLI
include_recipe "awscli"

# TODO: update nfs receipes to stop, disable nfs services
include_recipe "nfs"
include_recipe "nfs::server"

# Put configure-pat.sh onto the host
cookbook_file 'configure-pat.sh' do
  path '/usr/local/sbin/configure-pat.sh'
  user 'root'
  group 'root'
  mode '0744'
end

# Put setup-ephemeral-drives.sh onto the host
cookbook_file 'setup-ephemeral-drives.sh' do
  path '/usr/local/sbin/setup-ephemeral-drives.sh'
  user 'root'
  group 'root'
  mode '0744'
end

ec2_udev_rules_tarball = "#{node['cfncluster']['sources_dir']}/ec2-udev.tar.gz"

# Get ec2-udev-rules tarball
remote_file ec2_udev_rules_tarball do
  source node['cfncluster']['udev_url']
  mode '0644'
  # TODO: Add version or checksum checks
  not_if { ::File.exists?(ec2_udev_rules_tarball) }
end

# Install ec2-udev-rules
bash 'make install' do
  user 'root'
  group 'root'
  cwd Chef::Config[:file_cache_path]
  code <<-EOF
    tar xf #{ec2_udev_rules_tarball}
    cd ec2-udev-scripts-*
    make install
  EOF
  # TODO: Fix, so it works for upgrade
  creates '/usr/local/sbin/attachVolume.py'
end

# Install ec2-metadata script
remote_file '/usr/bin/ec2-metadata' do
  source 'http://s3.amazonaws.com/ec2metadata/ec2-metadata'
  user 'root'
  group 'root'
  mode '0755'
end

# Install cfncluster-nodes packages
python_pip "cfncluster-node"

# Supervisord
python_pip "supervisor"

# Put supervisord config in place
cookbook_file "supervisord.conf" do
  path "/etc/supervisord.conf"
  owner "root"
  group "root"
  mode "0644"
end

# Put init script in place
cookbook_file "supervisord-init" do
  path "/etc/init.d/supervisord"
  owner "root"
  group "root"
  mode "0755"
end

# Install lots of packages
node['cfncluster']['base_packages'].each do |p|
  package p
end

# Install Ganglia
include_recipe "cfncluster::_ganglia_install"
