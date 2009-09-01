class ContigsController < ApplicationController
  # GET /contigs
  # GET /contigs.xml
  def index
    @contigs = Contig.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @contigs }
    end
  end

  # GET /contigs/current
  def current
    @contigs = Contig.current_contigs(params[:minlen])

    respond_to do |format|
      format.html { render :template => 'contigs/index.html' }
      format.json { render :layout => false, :json => @contigs.to_json }
      format.xml  { render :xml => @contigs }
    end
  end

  # GET /contigs/1
  # GET /contigs/1.xml
  def show
    @contig = Contig.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @contig }
    end
  end

  # GET /contigs/new
  # GET /contigs/new.xml
  def new
    @contig = Contig.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @contig }
    end
  end

  # GET /contigs/1/edit
  def edit
    @contig = Contig.find(params[:id])
  end

  # POST /contigs
  # POST /contigs.xml
  def create
    @contig = Contig.new(params[:contig])

    respond_to do |format|
      if @contig.save
        flash[:notice] = 'Contig was successfully created.'
        format.html { redirect_to(@contig) }
        format.xml  { render :xml => @contig, :status => :created, :location => @contig }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @contig.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /contigs/1
  # PUT /contigs/1.xml
  def update
    @contig = Contig.find(params[:id])

    respond_to do |format|
      if @contig.update_attributes(params[:contig])
        flash[:notice] = 'Contig was successfully updated.'
        format.html { redirect_to(@contig) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @contig.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /contigs/1
  # DELETE /contigs/1.xml
  def destroy
    @contig = Contig.find(params[:id])
    @contig.destroy

    respond_to do |format|
      format.html { redirect_to(contigs_url) }
      format.xml  { head :ok }
    end
  end

  # LIST TAGS /contigs/tags/1
  def tags
    @contig = Contig.find(params[:id])
    @mappings = @contig.tag_mappings.sort {|x,y| x.cstart <=> y.cstart }

    respond_to do |format|
      format.html
      format.xml { render :xml => @mappings.to_xml(:include => :tag) }
      format.json { render :layout => false,
                    :json => @mappings.to_json(:include => :tag) }
    end
  end

  # NEW TAG /contigs/add_tag/1
  def add_tag
    @contig = Contig.find(params[:id])
  end

  # SHOW SEQUENCE /contigs/show_sequence/1
  def sequence
    @contig = Contig.find(params[:id])

    @depad = !params[:depad].nil? && params[:depad] == 'true'

    respond_to do |format|
      format.html
      format.text  { render :text => @contig.to_fasta(@depad, true) }
    end
  end

  # EXPORT CURRENT CONTIGS /contigs/export
  def export
    @contigs = Contig.current_contigs(params[:minlen])

    @depad = !params[:depadded].nil? && params[:depadded] == 'true'

    respond_to do |format|
      format.html { render :template => 'projects/export.html' }
      format.text { render :template => 'projects/export.text' }
      format.xml { render :xml => @contigs }
    end
  end

  # SHOW PARENTS /contigs/1/parents
  def parents
    @contig = Contig.find(params[:id])
    @parents = @contig.parents

    respond_to do |format|
      format.html
      format.xml  { render :xml => @parents }
    end
  end
end
