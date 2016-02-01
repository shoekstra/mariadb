require 'spec_helper'

describe 'debian::mariadb::galera55' do
  let(:chef_run) do
    runner = ChefSpec::SoloRunner.new(platform: 'debian', version: '7.4',
                                      step_into: ['mariadb_configuration']
                                     ) do |node|
      node.automatic['memory']['total'] = '2048kB'
      node.automatic['ipaddress'] = '1.1.1.1'
      node.set['mariadb']['install']['version'] = '5.5'
      node.set['mariadb']['rspec'] = true
    end
    runner.converge('mariadb::galera')
  end
  let(:shellout) do
    double(run_command: nil, error!: nil, error?: true, stdout: '1',
           stderr: double(empty?: true), exitstatus: 0, :live_stream= => nil)
  end
  before do
    allow(Mixlib::ShellOut).to receive(:new).and_return(shellout)
    stub_search(:node, 'mariadb_galera_cluster_name:galera_cluster')
      .and_return([stub_node('galera1'), stub_node('galera2')])
    stub_search("mariadb", "id:root").and_return([{'password' => 'encrypted_password'}])
    allow(Chef::EncryptedDataBagItem).to receive(:load_secret).with('/etc/chef/encrypted_data_bag_secret').and_return('secret_key')
    allow(Chef::EncryptedDataBagItem).to receive(:load).with('mariadb', 'root', 'secret_key').and_return({'password' => 'root_password'})
  end

  it 'Installs Mariadb package' do
    expect(chef_run).to install_package('mariadb-galera-server-5.5')
  end

  it 'Configure MariaDB' do
    expect(chef_run).to render_file('/etc/mysql/my.cnf')
      .with_content(/table_open_cache	= 400/)
  end

  it 'Configure InnoDB' do
    expect(chef_run).to render_file('/etc/mysql/conf.d/20-innodb.cnf')
      .with_content(/innodb_buffer_pool_size = 256M/)
  end

  it 'Configure Replication' do
    expect(chef_run).to render_file('/etc/mysql/conf.d/30-replication.cnf')
      .with_content(%r{^log_bin = /var/log/mysql/mariadb-bin$})
  end

  it 'Create Galera conf file' do
    expect(chef_run).to add_mariadb_configuration('90-galera')
    expect(chef_run).to create_template('/etc/mysql/conf.d/90-galera.cnf')
      .with(
        user:  'root',
        group: 'mysql',
        mode:  '0640'
      )
  end

  it 'Create Debian conf file' do
    expect(chef_run).to create_template('/etc/mysql/debian.cnf')
      .with(
        user:  'root',
        group: 'root',
        mode:  '0600'
      )
  end
end
