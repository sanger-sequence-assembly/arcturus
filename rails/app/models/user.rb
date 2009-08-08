require 'net/ldap'

class User < ActiveRecord::Base
  set_table_name 'USER'
  self.primary_key = "username"

  config = YAML::load(File.open("#{RAILS_ROOT}/config/ldap/user.yml"))

  @@ldap = Net::LDAP.new(:host => config['host'], :port => config['port'], :base => config['base'])

  @@base = config['base']

  def full_name
    if @my_full_name.nil?
      execute_ldap_lookup
    end
    @my_full_name
  end

  def given_name
    if @my_given_name.nil?
      execute_ldap_lookup
    end
    @my_given_name
  end

  def family_name
    if @my_family_name.nil?
      execute_ldap_lookup
    end
    @my_family_name
  end

  @@manager_roles = ['coordinator', 'team leader'].freeze

  @@administrator_roles = ['administrator'].freeze

  @@finisher_roles = ['finisher'].freeze

  @@annotator_roles = ['annotator'].freeze

  @@all_roles = @@manager_roles | @@administrator_roles | @@finisher_roles | @@annotator_roles | [ "none" ]
  @@all_roles.sort!
  @@all_roles.freeze

  def has_finisher_role?
    @@finisher_roles.include?(role)
  end

  def has_manager_role?
    @@manager_roles.include?(role)
  end

  def has_annotator_role?
    @@annotator_roles.include?(role)
  end

  def has_administrator_role?
    @@administrator_roles.include?(role)
  end

  def self.all_roles
    @@all_roles
  end

protected

  def validate
    errors.add(:role, "not recognised") if !role.nil? & !@@all_roles.include?(role)
    errors.add(:username, "not known to LDAP") unless validate_via_ldap
  end

private

  def validate_via_ldap
    filter = Net::LDAP::Filter.eq("uid", username)

    entry =  @@ldap.search(:base => @@base, :filter => filter).first

    !entry.nil?
  end

  def execute_ldap_lookup
    filter = Net::LDAP::Filter.eq("uid", username)

    @entry =  @@ldap.search(:base => @@base, :filter => filter).first

    if @entry.nil?
      @my_full_name = "(Name unknown)"
      @my_given_name = ""
      @my_family_name = ""
    else
      @my_full_name = @entry['cn'].first
      @my_given_name = @entry['givenName'].nil? ? "" : @entry['givenName'].first
      @my_family_name = @entry['sn'].nil? ? "" : @entry['sn'].first
    end
  end
end
