require 'test_helper'

class ProjectsControllerTest < ActionController::TestCase
  set_fixture_class :ASSEMBLY => Assembly,
                    :PROJECT  => Project,
                    :CONTIG   => Contig

  fixtures :ASSEMBLY, :PROJECT, :CONTIG

  def setup
    @request_parameters = {:instance => 'testing', :organism => 'TESTDB_ADH'}
  end

  test "should get index" do
    get :index, @request_parameters
    assert_response :success
    assert_not_nil assigns(:projects)
  end

  test "should get new" do
    get :new, @request_parameters
    assert_response :success
  end

#  test "should create project" do
#    assert_difference('Project.count') do
#      post :create, :project => { }
#    end

#    assert_redirected_to project_path(assigns(:project))
#  end

#  test "should show project" do
#    get :show, :id => projects(:one).to_param
#    assert_response :success
#  end

#  test "should get edit" do
#    get :edit, :id => projects(:one).to_param
#    assert_response :success
#  end

#  test "should update project" do
#    put :update, :id => projects(:one).to_param, :project => { }
#    assert_redirected_to project_path(assigns(:project))
#  end

#  test "should destroy project" do
#    assert_difference('Project.count', -1) do
#      delete :destroy, :id => projects(:one).to_param
#    end

#    assert_redirected_to projects_path
#  end
end
