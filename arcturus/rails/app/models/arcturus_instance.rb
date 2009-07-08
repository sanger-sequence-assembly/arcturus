class ArcturusInstance
  def initialize(my_instance_name, my_subclass_name)
    @instance_name = my_instance_name
    @subclass_name = my_subclass_name
    build_inventory
  end

  def organisms
    @organisms
  end

  def instance_name
    @instance_name
  end

  def subclass_name
    @subclass_name
  end

private

  def build_inventory
    filter = Net::LDAP::Filter.eq("objectClass", "javaNamingReference")
    base = "cn=#{@instance_name}," + LDAP_BASE

    unless @subclass_name.nil?
      base = "cn=#{@subclass_name}," + base
    end

    entries = LDAP.search(:base => base, :filter => filter)
    unless (entries) then
      display_name = @subclass_name.nil? ? @instance_name :"#{@instance_name}/#{@subclass_name}"
      raise "Unknown instance: #{display_name}"
    end

    @organisms = {}

    entries.each do |entry|
      @organisms[entry['cn'].first] = entry['description'].first
    end

    @organisms.sort
  end
end
