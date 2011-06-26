module TimelineFu
  module Fires
    def self.included(klass)
      klass.send(:extend, ClassMethods)
    end
    
    module ClassMethods
      def fire(event_type, opts)
        opts[:subject] = :self unless opts.has_key?(:subject)
        opts[:event_type] = event_type.to_s
        
        TimelineEvent.create!(opts)
      end
      
      def fires(event_type, opts)
        raise ArgumentError, "Argument :on is mandatory" unless opts.has_key?(:on)

        # Array provided, set multiple callbacks
        if opts[:on].kind_of?(Array)
          opts[:on].each { |on| fires(event_type, opts.merge({:on => on})) }
          return
        end

        opts[:subject] = :self unless opts.has_key?(:subject)

        on = opts.delete(:on)
        _if = opts.delete(:if)
        _unless = opts.delete(:unless)

        case on
          when /(.+)_(.+)/  then order = $1; event = $2;
          else order = 'after'; event = on;
        end

        method_name = :"fire_#{event_type}_#{order}_#{event}"
        define_method(method_name) do
          create_options = opts.keys.inject({}) do |memo, sym|
            case opts[sym]
            when :self
              memo[sym] = self
            else
              memo[sym] = (respond_to?(opts[sym]) ? send(opts[sym]) : opts[sym].to_s) if opts[sym]
            end
            memo
          end
          create_options[:event_type] = (respond_to?(event_type) ? send(event_type) : event_type.to_s)

          # Cache actor/subjects
          
          create_options[:actor_data] = create_options[:actor].to_yaml rescue nil unless create_options[:actor].blank?
          create_options[:subject_data] = create_options[:subject].to_yaml rescue nil unless create_options[:subject].blank?
          create_options[:secondary_subject_data] = create_options[:secondary_subject].to_yaml rescue nil unless create_options[:secondary_subject].blank?

          create_options[:subject] = nil if create_options[:subject].present? && create_options[:subject].new_record?

          TimelineEvent.create!(create_options)
        end

        send(:"#{order}_#{event}", method_name, :if => _if, :unless => _unless)
      end
    end
  end
end
