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
  def list_tags
    @contig = Contig.find(params[:id])
    @mappings = @contig.tag_mappings.sort {|x,y| x.cstart <=> y.cstart }

    respond_to do |format|
      format.html
      format.xml { render :xml => @mappings.to_xml(:include => :tag) }
    end
  end

  # NEW TAG /contigs/new_tag/1
  def new_tag
    @contig = Contig.find(params[:id])
  end

  # SHOW SEQUENCE /contigs/show_sequence/1
  def show_sequence
    @contig = Contig.find(params[:id])

    respond_to do |format|
      format.html
      format.text  { render :text => @contig.to_fasta }
    end
  end

end
