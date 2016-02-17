require 'spec_helper'

describe 'debian::mariadb::default' do
  let(:tcpsocket_obj) do
    double(
      'TCPSocket',
      close: true
    )
  end

  let(:chef_run) do
    runner = ChefSpec::SoloRunner.new(platform: 'debian', version: '7.4',
                                      step_into: ['mariadb_configuration']
                                     ) do |node|
      node.automatic['memory']['total'] = '2048kB'
      node.automatic['ipaddress'] = '1.1.1.1'
    end
    runner.converge('mariadb::default')
  end
  before do
    allow(TCPSocket).to receive(:new).and_return(tcpsocket_obj)
  end

  it 'Configure includedir in /etc/mysql/my.cnf' do
    expect(chef_run).to create_template('/etc/mysql/my.cnf')
    expect(chef_run).to render_file('/etc/mysql/my.cnf')
      .with_content(%r{/etc/mysql/conf.d})
  end

  it 'Installs Mariadb package' do
    expect(chef_run).to install_package('mariadb-server-10.0')
  end

  it 'Installs debconf-utils package' do
    expect(chef_run).to install_package('debconf-utils')
  end

  it 'Configure InnoDB with attributes' do
    expect(chef_run).to add_mariadb_configuration('20-innodb')
    expect(chef_run).to render_file('/etc/mysql/conf.d/20-innodb.cnf')
      .with_content(/innodb_buffer_pool_size = 256M/)
    expect(chef_run).to create_template('/etc/mysql/conf.d/20-innodb.cnf')
      .with(
        user:  'root',
        group: 'mysql',
        mode:  '0640'
      )
  end

  it 'Configure Replication' do
    expect(chef_run).to add_mariadb_configuration('30-replication')
    expect(chef_run).to create_template('/etc/mysql/conf.d/30-replication.cnf')
  end

  it 'Configure Preseeding' do
    expect(chef_run).to create_directory('/var/cache/local/preseeding')
    expect(chef_run).to create_template('/var/cache/local/' \
                                        'preseeding/mariadb-server.seed')
  end

  it 'execute preseeding load' do
    execute = chef_run.execute('preseed mariadb-server')
    expect(execute).to do_nothing
  end

  it 'restart mysql service' do
    expect(chef_run).to_not restart_service('mysql')
  end

  it 'Create Grants file' do
    expect(chef_run).to create_template('/etc/mariadb_grants')
  end

  it 'execute grants file' do
    execute = chef_run.execute('install-grants')
    expect(execute).to do_nothing
  end

  it 'Execute service restart is not needed' do
    expect(chef_run).to_not run_execute('mariadb-service-restart-needed')
  end
  context 'use data bags' do
    let(:chef_run) do
      runner = ChefSpec::SoloRunner.new(platform: 'debian', version: '7.4',
        step_into: ['mariadb_configuration']) do |node|
        node.automatic['memory']['total'] = '2048kB'
        node.automatic['ipaddress'] = '1.1.1.1'
      end
      runner.converge('mariadb::default')
    end

    before do
      stub_search('mariadb', 'id:root').and_return([{'id' => 'root', 'root' => 'root_password'}])
      allow(Chef::EncryptedDataBagItem).to receive(:load_secret).with('/etc/chef/encrypted_data_bag_secret').and_return('secret key')
      allow(Chef::EncryptedDataBagItem).to receive(:load).with('mariadb', 'root', 'secret key').and_return({'root' => 'root_password'})
    end

    it 'Configure Preseeding' do
      expect(chef_run).to create_directory('/var/cache/local/preseeding')
      expect(chef_run).to create_template('/var/cache/local/preseeding/mariadb-server.seed').with(
        variables: {
          package_name: 'mariadb-server',
          rootpass: 'root_password'
        }
      )
    end
  end
end

describe 'debian::mariadb::client' do
  let(:chef_run) do
    runner = ChefSpec::SoloRunner.new(platform: 'debian', version: '7.4',
                                      step_into: ['mariadb_configuration']
                                     ) do |node|
      node.automatic['memory']['total'] = '2048kB'
      node.automatic['ipaddress'] = '1.1.1.1'
    end
    runner.converge('mariadb::client')
  end

  it 'Install MariaDB Client Package' do
    expect(chef_run).to install_package('mariadb-client-10.0')
  end

  it 'Install MariaDB Client Devel Package' do
    expect(chef_run).to install_package('libmariadbclient-dev')
  end
  context 'Without development files' do
    let(:chef_run) do
      runner = ChefSpec::SoloRunner.new(platform: 'debian', version: '7.4',
                                        step_into: ['mariadb_configuration']
                                       ) do |node|
        node.automatic['memory']['total'] = '2048kB'
        node.automatic['ipaddress'] = '1.1.1.1'
        node.set['mariadb']['client']['development_files'] = false
      end
      runner.converge('mariadb::client')
    end

    it 'Install MariaDB Client Package' do
      expect(chef_run).to install_package('mariadb-client-10.0')
    end

    it 'Don t install MariaDB Client Devel Package' do
      expect(chef_run).to_not install_package('libmariadbclient-dev')
    end
  end
end
