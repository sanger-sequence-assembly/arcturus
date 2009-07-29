require 'test_helper'

class ContigTagTest < ActiveSupport::TestCase
  fixtures :CONTIG, :CONTIGTAG, :TAG2CONTIG

  def setup
    @default_contig  = CONTIG(:default_contig)
  end

  test "find default tag" do
    tag = ContigTag.find_by_systematic_id('default_tag')
    assert_not_nil(tag)
    assert_equal tag.tagtype, "DFLT"
  end

  test "Insert a new tag" do
    assert_difference('ContigTag.count') do
      tag = ContigTag.new
      tag.tagtype = 'TEST'
      tag.systematic_id = 'TEST0004'
      tag.save!
    end
  end

end
