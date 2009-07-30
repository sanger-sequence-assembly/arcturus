require 'test_helper'

class ContigTest < ActiveSupport::TestCase
  set_fixture_class :ASSEMBLY => Assembly,
                    :PROJECT  => Project,
                    :CONTIG   => Contig

  fixtures :ASSEMBLY, :PROJECT, :CONTIG

  def setup
    @default_project  = PROJECT(:default_project)
    @bin_project      = PROJECT(:bin)
  end

  test "find default contig" do
    contig = Contig.find_by_gap4name('default_contig')
    assert_not_nil(contig)
    assert_equal contig.project_id, @default_project.project_id
  end

  test "valid project id" do
    contig = Contig.new(:gap4name   => 'new_contig',
                        :project_id => 0,
                        :created    => Time.now)

    assert !contig.save
  end

  test "invalid with missing attributes" do
    contig = Contig.new

    assert !contig.valid?

    assert contig.errors.invalid?(:project)
    assert contig.errors.invalid?(:length)
    assert contig.errors.invalid?(:nreads)
  end

  test "set project to bin" do
    contig = Contig.find_by_gap4name('default_contig')
    assert_not_nil(contig)
    contig.project = @bin_project
    assert_equal contig.project_id, @bin_project.project_id
    assert contig.save
    contig.reload
    assert_equal contig.project_id, @bin_project.project_id
  end

  test "cannot delete parent project" do
    contig = Contig.find_by_gap4name('default_contig')
    assert_not_nil(contig)
    assert_raise(ActiveRecord::StatementInvalid) {
      contig.project.delete
    }
  end
end
