class User < ActiveRecord::Base
  set_table_name 'USER'
  self.primary_key = "username"

  def full_name
    if @my_full_name.nil?
      @filter = Net::LDAP::Filter.eq("uid", username)

      @entry =  LDAP.search(:base => LDAP_PEOPLE_BASE, :filter => @filter).first

      if @entry.nil?
        @my_full_name = "(Name unknown)"
      else
        @my_full_name = @entry['cn'].first
      end
    end
    @my_full_name
  end
end
