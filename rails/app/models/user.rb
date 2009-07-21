require 'net/ldap'

class User < ActiveRecord::Base
  set_table_name 'USER'
  self.primary_key = "username"

  config = YAML::load(File.open("#{RAILS_ROOT}/config/ldap/user.yml"))

  @@ldap = Net::LDAP.new(:host => config['host'], :port => config['port'], :base => config['base'])

  @@base = config['base']

  def full_name
    if @my_full_name.nil?
      filter = Net::LDAP::Filter.eq("uid", username)

      @entry =  @@ldap.search(:base => @@base, :filter => filter).first

      if @entry.nil?
        @my_full_name = "(Name unknown)"
      else
        @my_full_name = @entry['cn'].first
      end
    end
    @my_full_name
  end
end
