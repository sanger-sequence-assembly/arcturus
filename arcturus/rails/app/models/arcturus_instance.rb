class ArcturusInstance

  attr_accessor :instance_name
  attr_accessor :group_name
  attr_accessor :genus_name

  def initialize
    @organisms = []
  end

  def add_organism_name (organism)
    @organisms << organism   
  end

  def inventory
    @organisms.sort
  end

  def selection_name
    selection_name = "#{self.instance_name}" # force to be string (aot a symbol)
    selection_name = "#{selection_name}-" + self.group_name if self.group_name
    selection_name = "#{selection_name}-" + self.genus_name if self.genus_name
    selection_name
  end

  def to_string
    length = @organisms.length
    puts "instance_name #{selection_name} has #{length} organisms"
  end
 
end
