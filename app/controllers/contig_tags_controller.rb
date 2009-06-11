class ContigTagsController < ApplicationController
  # GET /contig_tags
  # GET /contig_tags.xml
  def index
    @contig_tags = ContigTag.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @contig_tags }
    end
  end

  # GET /contig_tags/1
  # GET /contig_tags/1.xml
  def show
    @contig_tag = ContigTag.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @contig_tag }
    end
  end

  # GET /contig_tags/new
  # GET /contig_tags/new.xml
  def new
    @contig_tag = ContigTag.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @contig_tag }
    end
  end

  # GET /contig_tags/1/edit
  def edit
    @contig_tag = ContigTag.find(params[:id])
  end

  # POST /contig_tags
  # POST /contig_tags.xml
  def create
    @contig_tag = ContigTag.new(params[:contig_tag])

    respond_to do |format|
      if @contig_tag.save
        flash[:notice] = 'ContigTag was successfully created.'
        format.html { redirect_to(@contig_tag) }
        format.xml  { render :xml => @contig_tag, :status => :created, :location => @contig_tag }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @contig_tag.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /contig_tags/1
  # PUT /contig_tags/1.xml
  def update
    @contig_tag = ContigTag.find(params[:id])

    respond_to do |format|
      if @contig_tag.update_attributes(params[:contig_tag])
        flash[:notice] = 'ContigTag was successfully updated.'
        format.html { redirect_to(@contig_tag) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @contig_tag.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /contig_tags/1
  # DELETE /contig_tags/1.xml
  def destroy
    @contig_tag = ContigTag.find(params[:id])
    @contig_tag.destroy

    respond_to do |format|
      format.html { redirect_to(contig_tags_url) }
      format.xml  { head :ok }
    end
  end
end
