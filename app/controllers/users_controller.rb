class UsersController < ApplicationController
  # GET /users
  # GET /users.xml
  def index
    @users = User.find(:all, :conditions => "role is null or role != 'assembler'")

    @users.sort! { |a,b| a.family_name <=> b.family_name || a.given_name <=> b.given_name }

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @users }
    end
  end

  # GET /users/1
  # GET /users/1.xml
  def show
    @user = User.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @user }
    end
  end

  # GET /users/new
  # GET /users/new.xml
  def new
    @user = User.new

    @roles = User.all_roles

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @user }
    end
  end

  # GET /users/1/edit
  def edit
    @user = User.find(params[:id])

    @roles = User.all_roles

    respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @user }
    end

  end

  # POST /users
  # POST /users.xml
  def create
    @user = User.new
    @user.username = params[:user]['username']

    new_role = params[:user]['role']
    @user.role = new_role == 'none' ? nil : new_role

    respond_to do |format|
      if @user.save!
        flash[:notice] = 'User was successfully created.'
        format.html { redirect_to({:action => "show", :instance => params[:instance], :organism => params[:organism], :id => @user}) }
        format.xml  { render :xml => @user, :status => :created, :location => @user }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /users/1
  # PUT /users/1.xml
  def update
    @user = User.find(params[:user]['username'])

    if params[:user]['role'] == 'none'
      params[:user]['role'] = nil
    end

    respond_to do |format|
      if @user.update_attributes(params[:user])
        flash[:notice] = 'User was successfully updated.'
        format.html { redirect_to({:action => "show", :instance => params[:instance], :organism => params[:organism], :id => @user}) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /users/1
  # DELETE /users/1.xml
  def destroy
    @user = User.find(params[:id])
    @user.destroy

    respond_to do |format|
      format.html { redirect_to(users_url) }
      format.xml  { head :ok }
    end
  end
end
