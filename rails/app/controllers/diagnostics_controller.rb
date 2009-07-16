class DiagnosticsController < ApplicationController
  def index
    @primary_object_types = [ Assembly, Contig, Project, ContigTag, TagMapping ]
    @connection_pools = Set.new

    @primary_object_types.each do |pot|
      @connection_pools.merge pot.connection_handler.connection_pools.values.to_set
    end

    respond_to do |format|
      format.html # index.html.erb
    end
  end
end
