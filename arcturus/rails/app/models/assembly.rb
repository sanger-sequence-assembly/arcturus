class Assembly < ArcturusDatabase
  has_many :project

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

end
