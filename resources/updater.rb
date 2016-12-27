#
# Cookbook Name:: chef-client
# Resource:: updater
#
# Copyright 2016, Will Jordan
# Copyright 2016, Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'mixlib/shellout'
provides 'chef_client_updater'

property :channel, [String, Symbol], default: :stable
property :prevent_downgrade, [true, false], default: false
property :version, [String, Symbol], default: :latest
property :post_install_action, String, default: 'exec'

action :update do
  if update_necessary?
    converge_by "Upgraded chef-client #{current_version} to #{desired_version}" do
      upgrade_command = Mixlib::ShellOut.new(mixlib_install.install_command)
      upgrade_command.run_command
    end
  end
end

action_class do
  def load_mixlib_install
    begin
      require 'mixlib/install'
    rescue LoadError
      Chef::Log.info('mixlib-install gem not found. Installing now')
      chef_gem "mixlib-install" do
        compile_time true if respond_to?(:compile_time)
      end

      require 'mixlib/install'
    end
  end

  def load_mixlib_versioning
    begin
      require 'mixlib/versioning'
    rescue LoadError
      Chef::Log.info('mixlib-versioning gem not found. Installing now')
      chef_gem "mixlib-versioning" do
        compile_time true if respond_to?(:compile_time)
      end

      require 'mixlib/versioning'
    end
  end

  def mixlib_install
    load_mixlib_install
    options = {
      product_name: 'chef',
      platform_version_compatibility_mode: true,
      channel: new_resource.channel.to_sym,
      product_version: new_resource.version == 'latest' ? :latest : new_resource.version

    }
    Mixlib::Install.new(options)
  end

  # why would we use this when mixlib-install has a current_version method?
  # well mixlib-version parses the manifest JSON, which might not be there.
  # ohai handles this better IMO
  def current_version
    node['chef_packages']['chef']['version']
  end

  def desired_version
    new_resource.version == 'latest' ? mixlib_install.available_versions.last : new_resource.version
  end

  # why wouldn't we use the built in update_available? method in mixlib-install?
  # well that would use current_version from mixlib-install and it has no
  # concept or preventing downgrades
  def update_necessary?
    load_mixlib_versioning
    cur_version = Mixlib::Versioning.parse(current_version)
    des_version = Mixlib::Versioning.parse(desired_version)
    new_resource.prevent_downgrade ?
      (desired_version > cur_version) :
      (desired_version != cur_version)
  end

end
