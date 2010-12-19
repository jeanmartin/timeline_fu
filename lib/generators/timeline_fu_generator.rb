require 'rails/generators'
require 'rails/generators/migration'

class TimelineFuGenerator < Rails::Generators::Base
  
  include Rails::Generators::Migration
  
  def self.source_root
    @source_root ||= File.join(File.dirname(__FILE__), 'templates')
  end
  
  # Implement the required interface for Rails::Generators::Migration.
  # taken from http://github.com/rails/rails/blob/master/activerecord/lib/generators/active_record.rb
  def self.next_migration_number(dirname)
    if ActiveRecord::Base.timestamped_migrations
      Time.now.utc.strftime("%Y%m%d%H%M%S")
    else
     "%.3d" % (current_migration_number(dirname) + 1)
    end
  end
  
  def create_timeline_event_migration
    migration_template 'migration.rb', 'db/migrate/create_timeline_events.rb'
  end

  def copy_timeline_event_model
    copy_file "model.rb", "app/models/timeline_event.rb"
  end
  
end
