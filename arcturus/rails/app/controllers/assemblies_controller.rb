class AssembliesController < ApplicationController
  # GET /assemblies
  # GET /assemblies.xml
  def index
    @assemblies = Assembly.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @assemblies }
    end
  end

  # GET /assemblies/1
  # GET /assemblies/1.xml
  def show
    @assembly = Assembly.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @assembly }
    end
  end

  # GET /assemblies/new
  # GET /assemblies/new.xml
  def new
    @assembly = Assembly.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @assembly }
    end
  end

  # GET /assemblies/1/edit
  def edit
    @assembly = Assembly.find(params[:id])
  end

  # POST /assemblies
  # POST /assemblies.xml
  def create
    @assembly = Assembly.new(params[:assembly])

    respond_to do |format|
      if @assembly.save
        flash[:notice] = 'Assembly was successfully created.'
        format.html { redirect_to(@assembly) }
        format.xml  { render :xml => @assembly, :status => :created, :location => @assembly }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @assembly.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /assemblies/1
  # PUT /assemblies/1.xml
  def update
    @assembly = Assembly.find(params[:id])

    respond_to do |format|
      if @assembly.update_attributes(params[:assembly])
        flash[:notice] = 'Assembly was successfully updated.'
        format.html { redirect_to(@assembly) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @assembly.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /assemblies/1
  # DELETE /assemblies/1.xml
  def destroy
    @assembly = Assembly.find(params[:id])
    @assembly.destroy

    respond_to do |format|
      format.html { redirect_to(assemblies_url) }
      format.xml  { head :ok }
    end
  end
end