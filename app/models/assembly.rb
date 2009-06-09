class Assembly < ArcturusDatabase
  has_many :projects

  set_table_name 'ASSEMBLY'
  self.primary_key = "assembly_id"

  # def to_s
  #   self.name
  # end
end
