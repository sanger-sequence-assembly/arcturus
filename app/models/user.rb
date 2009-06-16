class User < ActiveRecord::Base
  set_table_name 'USER'
  self.primary_key = "username"
end
