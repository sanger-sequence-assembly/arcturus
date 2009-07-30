require 'test_helper'

class ProjectTest < ActiveSupport::TestCase
  fixtures :ASSEMBLY, :PROJECT

  def setup
    @default_assembly = ASSEMBLY(:default_assembly)
  end

  test "find default project" do
    assert_not_nil(Project.find_by_name('default_project'))
  end

  test "unique project name" do
    project = Project.new(:name => 'default_project',
                          :assembly => @default_assembly,
                          :creator => 'ejz',
                          :created => Time.now)

    assert_raise(ActiveRecord::StatementInvalid) {
      project.save
    }
  end

  test "valid assembly id" do
    project = Project.new(:name => 'new_project',
                          :assembly_id => 0,
                          :creator => 'ejz',
                          :created => Time.now)

    assert !project.save
  end

  test "invalid with missing attributes" do
    project = Project.new

    assert !project.valid?

    assert project.errors.invalid?(:name)
    assert project.errors.invalid?(:assembly)
  end
end
