module MysqlConnect

  require './config/reports_config.rb'

  def self.included receiver
    receiver.extend self
  end

  def mysql_client

    include ReportsConfig
    @config = config_values

    if @config[:mysql_ssh]
      gateway = Net::SSH::Gateway.new(@config[:mysql_host], @config[:mysql_ssh_username], :password => @config[:mysql_ssh_password])
      gateway.open('127.0.0.1', @config[:mysql_port], 3307)
      host = '127.0.0.1'
      port = 3307
    else
      host = @config[:mysql_host]
      port = @config[:mysql_port]
    end

    Mysql2::Client.new(:host => host, :username => @config[:archivesspace_mysql_username],
      :password => @config[:archivesspace_mysql_password], :database => @config[:archivesspace_mysql_database], :port => port)
  end

end
