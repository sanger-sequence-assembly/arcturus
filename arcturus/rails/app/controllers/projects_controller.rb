class ProjectsController < ApplicationController
  # GET /projects
  # GET /projects.xml

  def index

    @for_assembly = 0
    if params[:assembly_id] then
       @projects = Project.for_assembly_id(params[:assembly_id])
       @for_assembly = 1
    else
       @projects = Project.all
    end

    @assemblies_hash = Assembly.current_assemblies_as_hash

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

    @assemblies_hash = Assembly.current_assemblies_as_hash

    if params['assembly'] then
       @currentprojects = Project.for_assembly_id(params[:assembly])
    else
       @currentprojects = Project.all
       @assemblies = Assembly.current_assemblies
    end

    @project = Project.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @project }
    end
  end

  # GET /projects/1/edit
  def edit
    @project = Project.find(params[:id])
  end

  # POST /projects
  # POST /projects.xml
  def create
    # raise params[:project].inspect
    @project = Project.new(params[:project])

    @project.created = Time.now

    respond_to do |format|
      if @project.save
        flash[:notice] = 'Project was successfully created.'
        format.html { redirect_to( { :action => "show",
                                     :instance => params[:instance], 
                                     :organism => params[:organism],
                                     :id => @project}) }
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

    respond_to do |format|
      if @project.update_attributes(params[:project])
        flash[:notice] = 'Project was successfully updated.'
        format.html { redirect_to( { :action => "show",
                                     :instance => params[:instance],
                                     :organism => params[:organism],
                                     :id => @project}) }
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
    @project.destroy

    respond_to do |format|
      format.html { redirect_to(projects_url) }
      format.xml  { head :ok }
    end
  end

  # LIST CONTIGS /projects/list_contigs/1
  def list_contigs
    @project = Project.find(params[:id])
  end

  # EXPORT CONTIGS /projects/export_contigs/1
  def export_contigs
    @project = Project.find(params[:id])
    @contigs = @project.current_contigs

    respond_to do |format|
      format.html
      format.text
    end
  end
end
