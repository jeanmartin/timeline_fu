require 'rubygems'
require 'active_record'
require File.dirname(__FILE__)+'/../generators/timeline_fu/templates/model'
require File.dirname(__FILE__)+'/test_helper'
require 'shoulda'

class HasTimelineTest < Test::Unit::TestCase
  context "has_timeline associations" do
    setup do
      @james = create_person(:email => 'james@giraffesoft.ca')
      @mat   = create_person(:email => 'mat@giraffesoft.ca')
      @list = List.new(hash_for_list(:author => @james))
      @list.save
      @comment1 = Comment.new(:body => 'cool list!', :author => @james, :list => @list)
      @comment1.save
      @comment2 = Comment.new(:body => 'another cool list!', :author => @mat, :list => @list)
      @comment2.save
      @comment3 = Comment.new(:body => 'not using the l-word', :author => @mat, :list => @list)
      @comment3.save
    end
    
    # NOTE: potential extension - add functins to restrice to actor,subject or secondary_subject
    # could be implemented in the method_missing function
    # ie, given an association foo, check for foo_as_actor, foo_as_subject, etc
    
    should 'include events' do
      @comment2.body = 'YET another cool list!'
      @comment2.save
      
      assert @list.activity.all.map(&:subject).include? @comment1
      assert @list.activity.all.map(&:secondary_subject).include? @comment2
    end

    should 'generate from :all' do
      assert @james.activity.map(&:subject).include? @comment1
    end
    
    should "filter on condition" do
      #assert @james.activity.map(&:subject).include? @list
      assert !( @james.comment_activity.map(&:subject).include? @list )
      assert @james.comment_activity.map(&:subject).include? @comment1
    end

    should "respect order" do
      assert_equal @list, @list.activity.last.subject
      assert_equal @comment3, @list.activity.first.subject
    end
    
    context "after a list is destroyed" do
      setup do
        @list.destroy
      end
      
      should_change( "the number of events", :by => -4 ) { TimelineEvent.count } 
    end
  end
end
