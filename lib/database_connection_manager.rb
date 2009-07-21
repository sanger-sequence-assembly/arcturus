require 'net/ldap'

class DatabaseConnectionManager
  config = YAML::load(File.open("#{RAILS_ROOT}/config/ldap/database_connection_manager.yml"))

  @ldap = Net::LDAP.new(:host => config['host'], :port => config['port'], :base => config['base'])

  @base = config['base']

  @readonly_username = config['readonly_username']

  @readonly_password = config['readonly_password']

  def self.get_database_parameters(instance, organism)
    dbparams = lookup_database_parameters(instance, organism)

    change_database_parameters_if_testing(instance, dbparams)

    dbparams
  end

  def self.enumerate_entries(instance, subclass=nil)
    filter = Net::LDAP::Filter.eq("objectClass", "javaNamingReference")
    base = "cn=#{instance}," + @base

    unless subclass.nil?
      base = "cn=#{subclass}," + base
    end

    entries = @ldap.search(:base => base, :filter => filter)

    unless (entries) then
      display_name = subclass.nil? ? instance :"#{instance}/#{subclass}"
      raise "Unknown instance: #{display_name}"
    end

    organisms = {}

    entries.each do |entry|
      organisms[entry['cn'].first] = entry['description'].first
    end

    organisms
  end

private

  def self.lookup_database_parameters(instance, organism)
    filter = Net::LDAP::Filter.eq("cn", organism) &
             Net::LDAP::Filter.eq("objectClass", "javaNamingReference")

    base = "cn=#{instance}," + @base

    entry = @ldap.search(:base => base, :filter => filter).first

    if (entry.nil?)
      raise "Unknown organism: #{organism}"
    else
      build_database_parameters(entry['javareferenceaddress'])
    end
  end

  def self.build_database_parameters(parameters)
    values = {}

    parameters.each do |line|
      words = line.split "#"
      values[words[2]] = words[3]
    end

    {
      :adapter  => 'mysql',
      :host     => values['serverName'],
      :port     => values['port'].to_i,
      :database => values['databaseName'],
      :username => values['user'],
      :password => values['password']
    }
  end

  def self.change_database_parameters_if_testing(instance, dbparams)
    if (!dbparams.nil? && instance != "test" && RAILS_ENV != "production")     
      dbparams[:username] = @readonly_username
      dbparams[:password] = @readonly_password
    end
  end

end
