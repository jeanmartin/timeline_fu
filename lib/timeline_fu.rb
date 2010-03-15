#require 'timeline_fu/fires'
#require 'timeline_fu/has_timeline'
require File.dirname(__FILE__)+'/timeline_fu/fires'
require File.dirname(__FILE__)+'/timeline_fu/has_timeline'

module TimelineFu  
end

ActiveRecord::Base.send :include, TimelineFu::Fires
ActiveRecord::Base.send :include, TimelineFu::HasTimeline
