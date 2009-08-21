class Session < ActiveRecord::Base
  config = YAML::load(File.open("#{RAILS_ROOT}/config/models/session.yml"))[RAILS_ENV]
  Session.establish_connection(
    DatabaseConnectionManager.get_database_parameters(config['instance'], config['database'], false))

  set_table_name 'SESSION'

  self.primary_key = "username"
end
