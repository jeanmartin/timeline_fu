module TimelineFu
  module HasTimeline
    def self.included(klass)   
      klass.send(:extend, ClassMethods) 
      klass.send(:include, InstanceMethods)
    end

    module InstanceMethods
      attr_accessor :timeline_association_scopes, :timeline_association_orders
      
      private
      
      def handle_dependent_timelines
        self.class.timeline_association_dependent.each_pair do |name,dependent|
          case dependent
            when nil then return
            when :destroy then 
              self.send(name).each{|event| event.destroy()}
            when :delete_all then
              self.send(name).each{|event| event.delete()}
            else raise ArgumentError, "Not supported value for :dependent (#{dependent})"
          end
        end
      end
      
      def method_missing(method_id)    
        unless self.class.timeline_association_scopes.nil?  
          if self.class.timeline_association_scopes.key?( method_id )
            dynamic_scope = self.class.timeline_association_scopes[method_id].map{|as| self.class.generate_scope_name(method_id, as)}.join("_or_")
            scoped_tl = TimelineEvent.send( dynamic_scope, self.id )
            
            if self.class.timeline_association_orders.key?( method_id ) && scoped_tl.condition?(self.class.timeline_association_orders[method_id] )
              return scoped_tl.send( self.class.timeline_association_orders[method_id] )
            else
              return scoped_tl
            end
          else
            super
          end
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
        @timeline_association_scopes ||= {}
        @timeline_association_orders ||= {}
        @timeline_association_dependent ||={}
        class << self; attr_reader :timeline_association_scopes; end    
        class << self; attr_reader :timeline_association_orders; end  
        class << self; attr_reader :timeline_association_dependent; end  
        
        @timeline_association_scopes[name] = []
        @timeline_association_orders[name] = opts[:order] if opts.key?( :order )

        @timeline_association_dependent[name] = opts[:dependent]
        before_destroy :handle_dependent_timelines
        
        case 
          when opts[:as].kind_of?(Hash) then
            [:actor, :subject, :secondary_subject].each do |as|
              if (opts[:as].key? as)
                generate_as_scope(name, as, opts[:as][as]) 
                @timeline_association_scopes[name] << as
              end
            end
            
          when opts[:as].kind_of?(Array) then
            [:actor, :subject, :secondary_subject].each do |as|
              if (opts[:as].include? as)
                generate_as_scope(name, as)
                @timeline_association_scopes[name] << as
              end
            end       
               
          when opts[:as] == :all then
            [:actor, :subject, :secondary_subject].each do |as|
              generate_as_scope(name, as)
              @timeline_association_scopes[name] << as
            end
            
          when [:actor, :subject, :secondary_subject].include?(opts[:as]) then
            generate_as_scope(name, opts[:as])
            @timeline_association_scopes[name] << opts[:as]
          else raise ArgumentError, "Argument :as is mandatory and must be one of [:actor | :subject | :secondary_subject]"
        end
      end

      def generate_scope_name(association_name, as)
        "#{self.base_class.name.tableize}_#{association_name}_as_#{as}"
      end
            
      private
      
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
