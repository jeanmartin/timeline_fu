module TimelineFu
  module HasTimeline
    def self.included(klass)
      klass.send(:extend, ClassMethods)
    end

    module ClassMethods
      def has_timeline(name, opts)
      end
    end
  end
end
