require 'test_helper'

class ContigTagTest < ActiveSupport::TestCase
  set_fixture_class :CONTIGTAG   => ContigTag,
                    :TAG2CONTIG  => TagMapping,
                    :ASSEMBLY    => Assembly,
                    :PROJECT     => Project,
                    :CONTIG      => Contig

  fixtures :CONTIG, :CONTIGTAG, :TAG2CONTIG

  # Replace this with your real tests.
  test "the truth" do
    assert true
  end
end
