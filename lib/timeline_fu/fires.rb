module TimelineFu
  module Fires
    def self.included(klass)
      klass.send(:extend, ClassMethods)
    end

    module ClassMethods
      def fires(event_type, opts)
        raise ArgumentError, "Argument :on is mandatory" unless opts.has_key?(:on)

        # Array provided, set multiple callbacks
        if opts[:on].kind_of?(Array)
          opts[:on].each { |on| fires(event_type, opts.merge({:on => on})) }
          return
        end

        opts[:subject] = :self unless opts.has_key?(:subject)

        case opts[:on]
          when /(.+)_(.+)/  then order = $1; event = $2;
          else order = 'after'; event = opts[:on];
        end
          
        method_name = :"fire_#{event_type}_#{order}_#{event}"
        define_method(method_name) do
          create_options = [:actor, :subject, :secondary_subject].inject({}) do |memo, sym|
            case opts[sym]
            when :self
              memo[sym] = self
            else
              memo[sym] = send(opts[sym]) if opts[sym]
            end
            memo
          end
          create_options[:event_type] = event_type.to_s

          TimelineEvent.create!(create_options)
        end

        send(:"#{order}_#{event}", method_name, :if => opts[:if])
      end
    end
  end
end
