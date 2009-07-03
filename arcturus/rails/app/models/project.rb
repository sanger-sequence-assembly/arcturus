class Project < ArcturusDatabase
  set_table_name 'PROJECT'
  set_primary_key "project_id"

  belongs_to :assembly
  belongs_to :owner, :class_name => 'User', :foreign_key => 'owner'
  has_many :contig

  validates_presence_of :name
  validates_presence_of :creator
  validates_presence_of :assembly

  def owner=(user)
    new_owner = (user.nil? or user.kind_of? User) ? user : User.find(user)
    puts "new_owner = #{new_owner.inspect}"
    write_attribute(:owner, new_owner)
  end
 
  def current_contigs_summary
    @query = "select sum(length) as total_length,count(*) as contig_count," +
      " max(length) as max_length,sum(nreads) as read_count," +
      " max(updated) as last_update from CURRENTCONTIGS " +
      " where project_id = #{project_id}"
    connection.select_all(@query).first
  end

  def current_contigs
    Contig.find_by_sql("select * from CONTIG where contig_id in (select contig_id from CURRENTCONTIGS where project_id = #{project_id}) order by length desc")
  end

  def self.status_enumeration
    @columns = connection.select_one("show columns from PROJECT like 'status'")
    @enum = @columns['Type']
    @enumlist = @enum.sub(/enum\(\'(.+)\'\)/,'\1')
    @enumlist.split('\',\'')
  end 

end
