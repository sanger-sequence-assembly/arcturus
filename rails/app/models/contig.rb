require 'zlib'

class Contig < ActiveRecord::Base
  set_table_name 'CONTIG'
  self.primary_key = "contig_id"

  belongs_to :project

  validates_presence_of :project
  validates_numericality_of :length
  validates_numericality_of :nreads

  has_many :tag_mappings
  has_many :tags, :through => :tag_mappings

  @@inflater = Zlib::Inflate.new

  def self.current_contigs(minlen = 0)
    minlen = minlen.to_i
    Contig.find_by_sql("select * from CONTIG where contig_id in (select contig_id from CURRENTCONTIGS where length > #{minlen})")
  end
 
  def get_consensus(depad=false)
    query = "select sequence from CONSENSUS where contig_id = #{contig_id}"
    cseq = connection.select_all(query).first
    if ! cseq.nil?
      @@inflater.reset
      seq = @@inflater.inflate(cseq['sequence'])
      @@inflater.finish
      if (depad)
        seq.gsub!("-", "")
      end
      seq
    else
      nil
    end
  end

  def to_fasta(depad=false, verbose=false)
    seq = get_consensus(depad)
    seqlen = seq.length
    fasta = String.new
    fasta.concat(">contig#{contig_id}")
    pad_state = depad ? 'depadded' : 'padded'

    if verbose
      cstr = created.strftime("%Y-%m-%d_%H:%M:%S")
      fasta.concat(" length=#{seqlen} #{pad_state} reads=#{nreads} created=#{cstr} project=#{project.name}")
    end

    fasta.concat("\n")
    0.step(seq.length, 50) do |offset|
      fasta.concat(seq.slice(offset, 50))
      fasta.concat("\n");
    end
    fasta
  end

  def parents
    Contig.find_by_sql("select * from CONTIG where contig_id in (select parent_id from C2CMAPPING where contig_id = #{contig_id}) order by contig_id desc")
  end

  def depadded_to_padded_mapping
    seq = get_consensus(false)

    padchar = "-"[0]

    pads = Array.new(seq.length) { |i| seq[i] == padchar ? nil : 0 }

    d = 0

    pads.each_index do |i|
      if pads[i].nil?
        d += 1
      else
        pads[i] = d
      end
    end

    pads.delete_if { |i| i.nil? }
  end

private

  def validate
    errors.add(:length, "must be a positive number") unless length > 0;
    errors.add(:nreads, "must be a positive number") unless nreads > 0;
  end
end
