require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::WriteFileAgent do
  before(:each) do
    @valid_options = Agents::WriteFileAgent.new.default_options
    @checker = Agents::WriteFileAgent.new(:name => "WriteFileAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
