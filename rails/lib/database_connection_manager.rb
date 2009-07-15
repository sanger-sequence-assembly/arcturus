class DatabaseConnectionManager

  def self.get_database_parameters(instance, organism)
    dbparams = lookup_database_parameters(instance, organism)

    change_database_parameters_if_testing(instance, dbparams)

    dbparams
  end

private

  def self.lookup_database_parameters(instance, organism)
    filter = Net::LDAP::Filter.eq("cn", organism) &
             Net::LDAP::Filter.eq("objectClass", "javaNamingReference")
    base = "cn=#{instance}," + LDAP_BASE

    entry = LDAP.search(:base => base, :filter => filter).first

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
      dbparams[:username] = MYSQL_READ_ONLY_USERNAME
      dbparams[:password] = MYSQL_READ_ONLY_PASSWORD
    end
  end

end
