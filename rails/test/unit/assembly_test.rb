require 'test_helper'

class AssemblyTest < ActiveSupport::TestCase
  set_fixture_class :ASSEMBLY => Assembly
  fixtures :ASSEMBLY

  test "find default assembly" do
    assert_not_nil(Assembly.find_by_name('default_assembly'))
  end

  test "unique assembly name" do
    assembly = Assembly.new(:name => 'default_assembly',
                            :creator => 'ejz',
                            :created => Time.now)

    assert_raise(ActiveRecord::StatementInvalid) {
      assembly.save
    }
  end
end
