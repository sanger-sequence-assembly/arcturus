class Assembly < ArcturusDatabase
  has_many :project

  validates_presence_of :name
  validates_presence_of :creator

  set_table_name 'ASSEMBLY'
  self.primary_key = "assembly_id"

  def projects
      @query = "select project_id from PROJECT where assembly_id = #{assembly_id} order by project_id"
  end

  def projects_summary
      @query = "select count(*) as project_count from PROJECT where assembly_id = #{assembly_id}"
      connection.select_all(@query).first
# total = Project.find(:assembly_id).sum(&:1) ???
  end

  def current_contigs_summary
      @query = "select sum(length) as total_length, count(*) as contig_count, " +
               "sum(nreads) as read_count from CURRENTCONTIGS,PROJECT,ASSEMBLY " +
               "where CURRENTCONTIGS.project_id = PROJECT.project_id " + 
               "and PROJECT.assembly_id = #{assembly_id}"
      connection.select_all(@query).first
  end

  def to_s
      self.name
  end

  def to_puts
    puts "status of Assembly instance #{self}"
    puts "name          #{self.name}"
    puts "chromosome    #{self.chromosome}"
    puts "size          #{self.size}"
    puts "progress      #{self.progress}"
    puts "comment      '#{self.comment}'"    
    puts "created       #{self.created}"
    puts "creator       #{self.creator}"
    puts "updated       #{self.updated}"
  end

  def before_create
      self.created ||= Time.now
  end 

  def self.current_assemblies
      Assembly.find(:all, :order => "name")
  end

  def self.current_assemblies_as_array 
      Assembly.find(:all, :order => "name").map { |a| [a.assembly_id, a.name] }
#      Assembly.all.map { |a| [a.assembly_id, a.name] }
#      current_assemblies.map { |a| [a.assembly_id, a.name] }
  end

  def self.current_assemblies_as_hash
      hash = Hash.new
#      current_assemblies.each do |a|
      self.all.each do |a|
          hash[a.assembly_id] = a.name
      end
      hash
  end

end
