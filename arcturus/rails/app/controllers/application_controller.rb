# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  require 'etc'

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password

  before_filter :get_database_connection

private

  def get_database_connection
    @dbparams = lookup_database_parameters(params['instance'], params['organism'])

    change_database_parameters_if_testing(params['instance'], @dbparams)

    # raise "instance = " + params['instance'] + ", RAILS_ENV = " + RAILS_ENV + ", username = " + @dbparams[:username]

    ActiveRecord::Base.establish_connection(@dbparams)
  end

  def lookup_database_parameters(instance, organism)
    @filter = Net::LDAP::Filter.eq("cn", organism)
    @base = "cn=#{instance}," + LDAP_BASE

    @entry = LDAP.search(:base => @base, :filter => @filter).first

    if (@entry.nil?)
      raise "Unknown organism: #{organism}"
    else
      build_database_parameters(@entry['javareferenceaddress'])
    end
  end

  def build_database_parameters(parameters)
    @values = {}

    parameters.each do |line|
      @words = line.split "#"
      @values[@words[2]] = @words[3]
    end

    {
      :adapter  => 'mysql',
      :host     => @values['serverName'],
      :port     => @values['port'].to_i,
      :database => @values['databaseName'],
      :username => @values['user'],
      :password => @values['password']
    }
  end

  def change_database_parameters_if_testing(instance, dbparams)
    if (instance == "pathogen" && RAILS_ENV != "production")
      dbparams[:username] = MYSQL_READ_ONLY_USERNAME
      dbparams[:password] = MYSQL_READ_ONLY_PASSWORD
    end
  end

  def current_user
    Etc.getlogin # (on all platforms)
  end

end
