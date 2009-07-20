class Session < ActiveRecord::Base
  Session.establish_connection(DatabaseConnectionManager.get_database_parameters('test', 'arcturus'))
  set_table_name 'USER'
  self.primary_key = "username"
end
