# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  require 'etc' # for user info, see method current_user

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password

  before_filter :get_database_connection

private

  def get_database_connection
 
    if (params['instance'] && params['organism']) then
# this branch applies to all controllers except the arcturus_controller
      @dbparams = lookup_database_parameters(params['instance'], params['organism'])

      change_database_parameters_if_testing(params['instance'], @dbparams)

      ActiveRecord::Base.establish_connection(@dbparams)

    else
# this branch applies exclusively to the arcturus controller
      options = {}

      if (params['action'] == 'index' || params['action'] == 'pathogen') then
# the :group and :genus info can be passed in the url as ?group=...&group=....
        options[:group] = params[:group] if params[:group]
        options[:group] = params[:id]    if params[:id]
        options[:genus] = params[:genus] if params[:genus]
        lookup_database_inventory(:pathogen,options)
        return 1
      elsif (params['action'] == 'test') then
        lookup_database_inventory(:test,{})
        return 1
      elsif (params['action']) then # accept as group definition
        options[:group] = params['action']
        options[:genus] = params[:genus] if params[:genus]
        options[:genus] = params[:id]    if params[:id]
        lookup_database_inventory(:pathogen,options)
      else
puts "else option invoked (should not occur)"
puts params.inspect
      end

      return 1
    end
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
      :instance => @values['instanceName'],
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

  def lookup_database_inventory(instance,options)

    @arcturus_instance = ArcturusInstance.new

    @arcturus_instance.instance_name = instance

    @base = "cn=#{instance}," + LDAP_BASE

    if (options[:group]) then
      @base = "cn=#{options[:group]}," + @base
      @arcturus_instance.group_name = options[:group]
      if (options[:genus]) then
        @base = "cn=#{options[:genus]}," + @base
        @arcturus_instance.genus_name = options[:genus]
      end
    end 

    @entry = LDAP.search(:base => @base)
    unless (@entry) then
      puts "undefined LDAP return for instance #{instance}"
      return 0
    end

    @entry.each do |e|
        @hash = build_database_parameters(e['javareferenceaddress'])
        next unless @hash[:database]
        @arcturus_instance.add_organism_name(@hash[:database])
    end
    @arcturus_instance.to_string # message on server log
  end

  def current_user
    Etc.getlogin # (on all platforms)
  end

end
