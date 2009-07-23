require 'test_helper'

class SessionsControllerTest < ActionController::TestCase
  fixtures :sessions

  test "profile without login" do
    get :profile
    assert_redirected_to :action => 'login'
  end

  test "bad password" do
    post :login, :username => 'fred', :password => 'ThisIsNotMyPassword'
    assert_redirected_to :action => 'access_denied'
  end

  test "profile via auth_key" do
    fred = Session.find_by_username('fred')
    @request.cookies["arcturus_auth_key_test"] = fred.auth_key
    get :profile
    assert_response :success
    assert_template 'profile'
  end

  test "profile via api_key" do
    fred = Session.find_by_username('fred')
    api_key = fred.api_key
    get :profile, :api_key => api_key
    assert_response :success
    assert_template 'profile'
  end
end
