class TagToContigsController < ApplicationController
  # GET /tag_to_contigs
  # GET /tag_to_contigs.xml
  def index
    @tag_to_contigs = TagToContig.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @tag_to_contigs }
    end
  end

  # GET /tag_to_contigs/1
  # GET /tag_to_contigs/1.xml
  def show
    @tag_to_contig = TagToContig.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @tag_to_contig }
    end
  end

  # GET /tag_to_contigs/new
  # GET /tag_to_contigs/new.xml
  def new
    @tag_to_contig = TagToContig.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @tag_to_contig }
    end
  end

  # GET /tag_to_contigs/1/edit
  def edit
    @tag_to_contig = TagToContig.find(params[:id])
  end

  # POST /tag_to_contigs
  # POST /tag_to_contigs.xml
  def create
    @tag_to_contig = TagToContig.new(params[:tag_to_contig])

    respond_to do |format|
      if @tag_to_contig.save
        flash[:notice] = 'TagToContig was successfully created.'
        format.html { redirect_to(@tag_to_contig) }
        format.xml  { render :xml => @tag_to_contig, :status => :created, :location => @tag_to_contig }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @tag_to_contig.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /tag_to_contigs/1
  # PUT /tag_to_contigs/1.xml
  def update
    @tag_to_contig = TagToContig.find(params[:id])

    respond_to do |format|
      if @tag_to_contig.update_attributes(params[:tag_to_contig])
        flash[:notice] = 'TagToContig was successfully updated.'
        format.html { redirect_to(@tag_to_contig) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @tag_to_contig.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /tag_to_contigs/1
  # DELETE /tag_to_contigs/1.xml
  def destroy
    @tag_to_contig = TagToContig.find(params[:id])
    @tag_to_contig.destroy

    respond_to do |format|
      format.html { redirect_to(tag_to_contigs_url) }
      format.xml  { head :ok }
    end
  end
end
