require 'net/ldap'

class AuthenticationManager
  config = YAML::load(File.open("#{RAILS_ROOT}/config/ldap/authentication_manager.yml"))

  @ldap = Net::LDAP.new(:host => config['host'], :port => config['port'], :encryption => :simple_tls, :base => config['base'])

  @base = config['base']

  def self.authenticate(username, password)
    authenticate_with_ldap(username, password)
  end

private

  def self.authenticate_with_ldap(username, password)
    @ldap.authenticate("uid=" + username + "," + @base, password)
    @ldap.bind
  end
end
