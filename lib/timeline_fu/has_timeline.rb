module TimelineFu
  module HasTimeline
    def self.included(klass)   
      klass.send(:extend, ClassMethods) 
      klass.send(:include, InstanceMethods)
    end

    module InstanceMethods
      private
      
      def handle_dependent_timelines
        self.class.tl_dependent.each_pair do |name,dependent|
          case dependent
            when nil          then return
            when :destroy     then self.send(name).each{|event| event.destroy()}
            when :delete_all  then self.send(name).each{|event| event.delete()}
            else              raise ArgumentError, "Not supported value for :dependent (#{dependent})"
          end
        end
      end
      
      def method_missing(method_id)    
        unless self.class.tl_scopes.nil?  
          base_scope = [self.class.name.tableize, method_id].join('_')
        
          if self.class.tl_scopes.key?( base_scope )
            get_scoped_events(base_scope)
          else
            super
          end
        end
      end  
      
      def get_scoped_events(base_scope)
        
        # build the association from scopes
        associated    = TimelineEvent.send  self.class.tl_scopes[base_scope].map{|s| [base_scope,s].join('_')}.join('_or_'), self.id
        conditioned   = associated.send     [base_scope, self.class.tl_conditions[base_scope]].join('_')

        if self.class.tl_orders[base_scope]
          return        conditioned.send    self.class.tl_orders[base_scope]
        else
          return conditioned
        end
      end      
    end
        
    module ClassMethods    
      def has_timeline(association_name, opts)
        opts.assert_valid_keys(
          :as,
          :conditions,
          :order,
          :dependent
        )  
        
        initialize_variables if @tl_scopes.nil?
        scopes_base_name = [self.base_class.name.tableize, association_name].join('_')
        @tl_scopes[scopes_base_name]      = []
        @tl_conditions[scopes_base_name]  = []
        @tl_orders[scopes_base_name]      = opts[:order] if opts.key?( :order )
        @tl_dependent[association_name]   = opts[:dependent]

        case 
          when opts[:as].kind_of?(Array) then generate_scopes_from_array( scopes_base_name, 
                                                                        opts[:as] )
          when opts[:as] == :all then generate_scopes_from_array( scopes_base_name, 
                                                                        [:actor, :subject, :secondary_subject] )
          when opts[:as].kind_of?(Symbol) then generate_scopes_from_symbol( scopes_base_name, 
                                                                        opts[:as] )
          else raise ArgumentError, "Argument :as not specified or incorrect type"
        end
        
        inject_named_scope( scopes_base_name, 'conditions', {:conditions => opts[:conditions]}, @tl_conditions )
      end
            
      private
      
      def initialize_variables
        before_destroy :handle_dependent_timelines
        class << self; attr_reader :tl_scopes, :tl_conditions, :tl_orders, :tl_dependent; end
        @tl_scopes          ||= {}
        @tl_conditions      ||= {}
        @tl_orders          ||= {}
        @tl_dependent       ||= {}
      end      
      
      def generate_scopes_from_array(base_name, array)
        array.each do |symbol|
          generate_scopes_from_symbol( base_name, symbol )
        end
      end
      
      def generate_scopes_from_symbol(base_name, symbol)
        scope_name = [symbol, 'scope'].join('_')
        inject_named_scope( base_name, scope_name, 
                          lambda { |*associated_id| { :conditions => 
                          { "#{symbol}_id".to_sym => associated_id.first, 
                          "#{symbol}_type".to_sym => self.base_class.name } } } )
      end
      
      def inject_named_scope( base_name, scope_name, conditions, i_var = @tl_scopes )
        TimelineEvent.class_eval do
          named_scope [base_name,scope_name].join('_'), conditions
        end

        i_var[base_name] << scope_name
      end
    end
  end
end
