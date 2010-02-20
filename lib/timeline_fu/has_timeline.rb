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
          if self.class.tl_scopes.key?( method_id )
            get_scoped_events(method_id)
          else
            super
          end
        end
      end  
      
      def get_scoped_events(association)
        dynamic_scopes = self.class.tl_scopes[association].map do 
          |as| self.class.generate_scope_name(association, as)
        end
        
        scoped_tl = TimelineEvent.send( dynamic_scopes.join("_or_"), self.id )
        
        if self.class.tl_orders.key?( association ) && scoped_tl.condition?(self.class.tl_orders[association] )
          return scoped_tl.send( self.class.tl_orders[association] )
        else
          return scoped_tl
        end
      end      
    end
        
    module ClassMethods    
      def has_timeline(name, opts)
        opts.assert_valid_keys(
          :as,
          :order,
          :dependent
        )  
        
        initialize_variables if @tl_scopes.nil?
        @tl_scopes[name]      = []
        @tl_orders[name]      = opts[:order] if opts.key?( :order )
        @tl_dependent[name]   = opts[:dependent]

        generate_scopes(name, opts[:as])
      end

      def generate_scope_name(association_name, as)
        "#{self.base_class.name.tableize}_#{association_name}_as_#{as}"
      end
            
      private
      
      def initialize_variables
        before_destroy :handle_dependent_timelines
        class << self; attr_reader :tl_scopes, :tl_orders, :tl_dependent; end
        @tl_scopes          ||= {}
        @tl_orders          ||= {}
        @tl_dependent       ||= {}
      end      
      
      def generate_scopes(name, as)
        case 
          when as.kind_of?(Hash) then
            [:actor, :subject, :secondary_subject].each do |a|
              if (as.key? a)
                generate_as_scope(name, a, as[a]) 
                @tl_scopes[name] << a
              end
            end
            
          when as.kind_of?(Array) then
            [:actor, :subject, :secondary_subject].each do |a|
              if (as.include? a)
                generate_as_scope(name, a)
                @tl_scopes[name] << a
              end
            end       
               
          when as == :all then
            [:actor, :subject, :secondary_subject].each do |a|
              generate_as_scope(name, a)
              @tl_scopes[name] << a
            end
            
          when [:actor, :subject, :secondary_subject].include?(as) then
            generate_as_scope(name, as)
            @tl_scopes[name] << as
          else raise ArgumentError, "Argument :as is mandatory and must be one of [:actor | :subject | :secondary_subject]"
        end      
      end
      
      def generate_as_scope(association_name, as, conditions = nil)
        class_name = self.base_class.name
        as_id = "#{as}_id"
        as_type = "#{as}_type"
        scope_name = generate_scope_name(association_name, as)

        case
          when conditions.kind_of?(Hash) || conditions.nil? then  
            TimelineEvent.class_eval do
              named_scope scope_name, lambda { |*associated_id| 
                conditions_hash = { as_id.to_sym => associated_id.first, as_type.to_sym => class_name }
                conditions_hash.merge!( conditions ) unless conditions.nil?
                { :conditions => conditions_hash }
              }
            end
            
          when conditions.kind_of?(Array) then
            TimelineEvent.class_eval do
              named_scope scope_name, lambda { |*associated| 
                condition_string = "#{as_id} = ? AND #{as_type} = ? AND " + conditions[0]
                condition_values = [associated_id.first, class_name] + conditions[1..conditions.count]
                { :conditions => [condition_string] + condition_values }
              }
            end  
            
          when conditions.kind_of?(String) then
            TimelineEvent.class_eval do
              named_scope scope_name, lambda { |*associated|
                condition_string = [as_id+' == '+associated_id.first+' AND '+as_type+' == '+class_name,conditions].join(' AND ')                        
                { :conditions => condition_string }
              }
            end  
        end              
      end
    end
  end
end
