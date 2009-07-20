class AuthenticationManager
  def self.authenticate(username, password)
    authenticate_with_ldap(username, password)
  end

private

  def self.authenticate_with_ldap(username, password)
    LDAP_PEOPLE.authenticate("uid=" + username + "," + LDAP_PEOPLE_BASE, password)
    LDAP_PEOPLE.bind
  end
end
