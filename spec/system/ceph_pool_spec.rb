#
# Copyright (C) 2014 Catalyst IT Limited.
# Copyright (C) 2014 Nine Internet Solutions AG
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
# Author: Ricardo Rocha <ricardo@catalyst.net.nz>
# Author: David Gurtner <david@nine.ch>
#
require 'spec_helper_system'

describe 'ceph::pool' do

  releases = [ 'dumpling', 'emperor', 'firefly' ]
  fsid = 'a4807c9a-e76f-4666-a297-6d6cbc922e3a'

  releases.each do |release|
    purge = <<-EOS
      Exec { path => [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ] }

      ceph::mon { 'a': ensure => absent }
      ->
      file { '/var/lib/ceph/bootstrap-osd/ceph.keyring': ensure => absent }
      ->
      package { [
         'python-ceph',
         'ceph-common',
         'librados2',
         'librbd1',
         'libcephfs1',
        ]:
        ensure => purged
      }
      class { 'ceph::repo':
        ensure => absent,
        release => '#{release}',
      }
    EOS

    describe release do
      it 'should install and create pool volumes' do
        pp = <<-EOS
          Exec { path => [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ] }

          class { 'ceph::repo':
            release => '#{release}',
          }
          ->
          class { 'ceph':
            fsid => '#{fsid}',
            mon_host => $::ipaddress_eth0,
            authentication_type => 'none',
          }
          ->
          ceph::mon { 'a':
            public_addr => $::ipaddress_eth0,
            authentication_type => 'none',
          }
          ->
          ceph::pool { 'volumes':
            pg_num  => 64,
            pgp_num => 64,
            size    => 3,
          }
        EOS

        puppet_apply(pp) do |r|
          r.exit_code.should_not == 1
          r.refresh
          r.exit_code.should_not == 1
        end

        shell 'ceph osd pool get volumes pg_num' do |r|
          r.stdout.should =~ /pg_num: 64/
          r.stderr.should be_empty
          r.exit_code.should be_zero
        end

        shell 'ceph osd pool get volumes pgp_num' do |r|
          r.stdout.should =~ /pgp_num: 64/
          r.stderr.should be_empty
          r.exit_code.should be_zero
        end

        shell 'ceph osd pool get volumes size' do |r|
          r.stdout.should =~ /size: 3/
          r.stderr.should be_empty
          r.exit_code.should be_zero
        end

      end

      it 'should install and delete pool volumes' do
        pp = <<-EOS
          Exec { path => [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ] }

          class { 'ceph::repo':
            release => '#{release}',
          }
          ->
          class { 'ceph':
            fsid => '#{fsid}',
            mon_host => $::ipaddress_eth0,
            authentication_type => 'none',
          }
          ->
          ceph::mon { 'a':
            public_addr => $::ipaddress_eth0,
            authentication_type => 'none',
          }
          ->
          exec { 'create-volumes':
            command => 'ceph osd pool create volumes 64',
          }
          ->
          ceph::pool { 'volumes':
            ensure => absent,
          }
        EOS

        puppet_apply(pp) do |r|
          r.exit_code.should_not == 1
          r.refresh
          r.exit_code.should_not == 1
        end

        shell 'ceph osd lspools | grep volumes' do |r|
          r.stdout.should be_empty
          r.stderr.should be_empty
          r.exit_code.should_not be_zero
        end

      end
      it 'should uninstall one monitor and all packages' do
        puppet_apply(purge) do |r|
          r.exit_code.should_not == 1
        end
      end

    end
  end

end
# Local Variables:
# compile-command: "cd ../..
#   (
#     cd .rspec_system/vagrant_projects/one-centos-64-x64
#     vagrant destroy --force
#   )
#   cp -a Gemfile-rspec-system Gemfile
#   BUNDLE_PATH=/tmp/vendor bundle install --no-deployment
#   MACHINES=first \
#   RELEASES=cuttlefish \
#   RS_DESTROY=no \
#   RS_SET=one-centos-64-x64 \
#   BUNDLE_PATH=/tmp/vendor \
#   bundle exec rake spec:system SPEC=spec/system/ceph_pool_spec.rb &&
#   git checkout Gemfile
# "
# End:
