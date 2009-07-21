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
    @organisms = DatabaseConnectionManager.enumerate_entries(@instance_name, @subclass_name)

    @organisms.sort
  end
end
