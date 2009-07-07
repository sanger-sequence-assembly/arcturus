ActionController::Routing::Routes.draw do |map|
  map.resources :contig_tags, :path_prefix => "/:instance/:organism"

  map.resources :tag_mappings, :path_prefix => "/:instance/:organism"

  map.connect ":instance/:organism/:controller"
  map.connect ":instance/:organism/:controller/:action"
  map.connect ":instance/:organism/:controller/:action/:id"
  map.connect ":instance/:organism/:controller/:action/:id.:format"

  map.connect "arcturus/:instance", :controller => 'arcturus', :action => 'index'
end
