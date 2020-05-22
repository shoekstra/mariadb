include_recipe 'test::server_install'

mariadb_server_configuration 'MariaDB Server Configuration' do
  version '10.3'
  mysqld_datadir '/opt/mysql'
  innodb_buffer_pool_size '256M'
end
