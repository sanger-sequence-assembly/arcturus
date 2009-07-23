require 'test_helper'

class SessionTest < ActiveSupport::TestCase
  fixtures :sessions

  test "find the test user" do
    fred = Session.find_by_username('fred')
    assert_not_nil(fred)
    assert_equal fred.role, "finisher"
    assert_equal fred.auth_key, "12345678901234567890123456789012"
    assert_equal fred.api_key, "12345678901234567890123456789012"
  end

  test "unique user name" do
    my_session = Session.new

    my_session.username = 'adh'
    my_session.role = 'finisher'

    assert my_session.save!
  end

  test "duplicate api_key" do
    fred = Session.find_by_username('fred')

    my_session = Session.new

    my_session.username = 'adh'
    my_session.role = 'finisher'
    my_session.api_key = fred.api_key

    assert_raise(ActiveRecord::StatementInvalid) {
      my_session.save
    }
  end

  test "duplicate auth_key" do
    fred = Session.find_by_username('fred')

    my_session = Session.new

    my_session.username = 'adh'
    my_session.role = 'finisher'
    my_session.auth_key = fred.auth_key

    assert_raise(ActiveRecord::StatementInvalid) {
      my_session.save
    }
  end

  test "find user by auth_key" do
    fred = Session.find_by_auth_key("12345678901234567890123456789012")
    assert_not_nil(fred)
    assert_equal fred.username, 'fred'
  end

  test "find user by api_key" do
    fred = Session.find_by_api_key("12345678901234567890123456789012")
    assert_not_nil(fred)
    assert_equal fred.username, 'fred'
  end

end
