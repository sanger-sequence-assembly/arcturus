class User < ActiveRecord::Base
  set_table_name 'USER'
  set_primary_key "username"

  def full_name
    @filter = Net::LDAP::Filter.eq("uid", username)

    @entry =  LDAP.search(:base => LDAP_PEOPLE_BASE, :filter => @filter).first

    if ! @entry.nil?
      @entry['cn'].first
    end
  end
end
