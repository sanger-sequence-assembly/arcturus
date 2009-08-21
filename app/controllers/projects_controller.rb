class ProjectsController < ApplicationController
  # GET /projects
  # GET /projects.xml

  def index
    @projects = Project.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @projects }
    end
  end

  # GET /projects/1
  # GET /projects/1.xml
  def show
    @project = Project.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @project }
    end
  end

  # GET /projects/new
  # GET /projects/new.xml
  def new

    if params['assembly'] then
       @currentprojects = Project.find_all_by_assembly_id(params[:assembly])
       @assembly = Assembly.find(params['assembly'].to_i)
    else
       @currentprojects = Project.all
       @assemblies = Assembly.current_assemblies
    end

    @project = Project.new

    @users = user_list_for_owner

    @status = Project.status_enumeration

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @project }
    end
  end

  # GET /projects/1/edit
  def edit
    @project = Project.find(params[:id])

    @assemblies = Assembly.current_assemblies

    @users = user_list_for_owner

    @status = Project.status_enumeration
  end

  # POST /projects
  # POST /projects.xml
  def create
    @project = Project.new(params[:project])

    @project.created = Time.now

    respond_to do |format|
      if @project.save
        flash[:notice] = "Project #{@project.name} was successfully created."
        format.html { redirect_to( { :action => "index",
                                     :instance => params[:instance], 
                                     :organism => params[:organism] }) }
        format.xml  { render :xml => @project, :status => :created, :location => @project }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @project.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /projects/1
  # PUT /projects/1.xml
  def update
    @project = Project.find(params[:id])

    if params[:project]['owner'] == 'nobody'
      params[:project]['owner'] = nil
    end

    respond_to do |format|
      if @project.update_attributes(params[:project])
        flash[:notice] = "Project #{@project.name} was successfully updated"
        format.html { redirect_to :action => "show",
                                  :instance => params[:instance],
                                  :organism => params[:organism],
                                  :id => @project }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @project.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/1
  # DELETE /projects/1.xml
  def destroy
    @project = Project.find(params[:id])

    @projectname = @project.name

    @project.destroy

    respond_to do |format|
      flash[:notice] = "Project #{@projectname} was deleted"
      format.html { redirect_to  :action => "index",
                                  :instance => params[:instance],
                                  :organism => params[:organism] }
      format.xml  { head :ok }
    end
  end

  # LIST CONTIGS /projects/1/contigs
  def contigs
    @project = Project.find(params[:id])
    @contigs = @project.current_contigs
    @summary = @project.current_contigs_summary

    respond_to do |format|
      format.html
      format.text
      format.xml { render :xml => @contigs }
    end
  end

  # EXPORT CONTIGS /projects/1/export
  def export
    @project = Project.find(params[:id])
    @contigs = @project.current_contigs

    @depad = !params[:depad].nil? && params[:depad] == 'true'

    respond_to do |format|
      format.html
      format.text
      format.xml { render :xml => @contigs }
    end
  end

private

  def user_list_for_owner
    users = User.find(:all)

    users.sort! { |a,b| a.family_name <=> b.family_name || a.given_name <=> b.given_name }

    nobody = User.new
    nobody.username = 'nobody'
    users << nobody

    users
  end
end
