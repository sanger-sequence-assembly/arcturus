class Project < ArcturusDatabase
  belongs_to :assembly
  has_many :contig

  set_table_name 'PROJECT'
  self.primary_key = "project_id"

  def current_contigs_summary
    @query = "select sum(length) as total_length,count(*) as contig_count," +
      " max(length) as max_length,sum(nreads) as read_count," +
      " max(updated) as last_update from CURRENTCONTIGS" +
      " where project_id = #{project_id}"
    connection.select_all(@query).first
  end

  def current_contig_list
    @query = "select contig_id,gap4name,length as basepairs,nreads as read_count,created,updated" +
	" from CURRENTCONTIGS where project_id = #{project_id} order by length desc"
    connection.select_all(@query)
  end
end
