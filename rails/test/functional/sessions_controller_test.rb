require 'test_helper'

class SessionsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:sessions)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create session" do
    assert_difference('Session.count') do
      post :create, :session => { }
    end

    assert_redirected_to session_path(assigns(:session))
  end

  test "should show session" do
    get :show, :id => sessions(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => sessions(:one).to_param
    assert_response :success
  end

  test "should update session" do
    put :update, :id => sessions(:one).to_param, :session => { }
    assert_redirected_to session_path(assigns(:session))
  end

  test "should destroy session" do
    assert_difference('Session.count', -1) do
      delete :destroy, :id => sessions(:one).to_param
    end

    assert_redirected_to sessions_path
  end
end
