class ArcturusInstance
  def initialize(my_instance_name)
    @instance_name = my_instance_name
    build_inventory
  end

  def organisms
    @organisms
  end

  def instance_name
    @instance_name
  end

private

  def build_inventory
    filter = Net::LDAP::Filter.eq("objectClass", "javaNamingReference")
    base = "cn=#{instance_name}," + LDAP_BASE

    entries = LDAP.search(:base => base, :filter => filter)
    unless (entries) then
      raise "Unknown instance: #{@instance_name}"
    end

    @organisms = {}

    entries.each do |entry|
      @organisms[entry['cn'].first] = entry['description'].first
    end

    @organisms.sort
  end
end
