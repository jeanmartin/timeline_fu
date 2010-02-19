require 'rubygems'
require 'activerecord'
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
    
    should 'include simply defined events' do
      @comment2.body = 'YET another cool list!'
      @comment2.save
      assert @list.simple_activity.map(&:subject).include? @comment1
      assert @list.simple_activity.map(&:secondary_subject).include? @comment2
    end

    should_eventually 'generate from :all' do
      assert @james.activity.map(&:subject).include? @comment1
    end

    should_eventually "include events from custom finder" do
      @comment2.body = 'YET another cool list!'
      @comment2.save
      assert @list.custom_activity.map(&:subject).include? @comment1
      assert @list.custom_activity.map(&:secondary_subject).include? @comment2
    end
    
    should_eventually "count from custom counter" do
      assert_equal 2, @list.custom_activity.count
    end
    
    should_eventually "filter on condition" do
      assert !( @list.simple_activity.map(&:subject).include? @comment3)
    end
    
    should_eventually "filter on multiple conditions" do
      @comment3.body = 'still not using the l-word'
      @comment3.save
      assert !(@list.custom_activity.map(&:subject).include? @comment3)
      assert @list.custom_activity.map(&:secondary_subject).include? @comment3
    end
    
    should_eventually "respect order" do
      assert @list.simple_activity.first.subject == @comment1
      assert @list.custom_activity.first.subject == @comment2
    end
    
    context "after a list is destroyed" do
      setup do
        @list.destroy
      end
      
      #should_change "TimelineEvent.count", :by => -2
    end
    
    context "after a comment is destroyed" do
      setup do
        @comment2.destroy
      end
      
      # Should destroy dependent update event and create a new deleted event
      #should_change "TimelineEvent.count", :by => 0
    end
  end
end
