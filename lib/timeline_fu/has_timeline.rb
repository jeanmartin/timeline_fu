module TimelineFu
  module HasTimeline
    def self.included(klass)   
      klass.send(:extend, ClassMethods) 
      klass.send(:include, InstanceMethods)
    end

    module InstanceMethods
      private
      
      def handle_dependent_timelines( association_name, dependent )
        case dependent
          when nil          then return
          when :destroy     then self.send(association_name).each{|event| event.destroy()}
          when :delete_all  then self.send(association_name).each{|event| event.delete()}
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
        
        scopes_base_name = [self.base_class.name.tableize, association_name].join('_')

        case 
          when opts[:as].kind_of?(Array)  then tl_scopes = generate_scopes_from_array( scopes_base_name, 
                                                                        opts[:as] )
          when opts[:as] == :all          then tl_scopes = generate_scopes_from_array( scopes_base_name, 
                                                                        [:actor, :subject, :secondary_subject] )
          when opts[:as].kind_of?(Symbol) then tl_scopes = [ generate_scopes_from_symbol( scopes_base_name, 
                                                                        opts[:as] ) ]
          else raise ArgumentError, "Argument :as not specified or incorrect type"
        end
        
        tl_conditions = inject_named_scope( scopes_base_name, 'conditions', {:conditions => opts[:conditions]} )
        
        send :define_method, association_name do
          # build the association from scopes
          [ [scopes_base_name, tl_conditions].join('_'), opts[:order] ].inject( 
            TimelineEvent.send( tl_scopes.map{|s| [scopes_base_name,s].join('_')}.join('_or_'), self.id ) 
          ) {|memo, obj| obj ? memo.send( obj ) : memo }
        end    
        
        before_destroy lambda { |object| object.send :handle_dependent_timelines, association_name, opts[:dependent] }
      end
            
      private    
      
      def generate_scopes_from_array(base_name, array)
        array.map do |symbol|
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
      
      def inject_named_scope( base_name, scope_name, conditions )
        TimelineEvent.class_eval do
          named_scope [base_name,scope_name].join('_'), conditions
        end

        scope_name
      end
    end
  end
end
