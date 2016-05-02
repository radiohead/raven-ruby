require 'spec_helper'

describe Raven::BreadcrumbBuffer do
  before(:each) do
    @breadcrumbs = Raven::BreadcrumbBuffer.new(10)
  end

  it 'works' do
    (0..10).each do |i|
      @breadcrumbs.record(Raven::Breadcrumb.new.tap {|b| b.message = i})
    end

    results = @breadcrumbs.each.to_a

    expect(results.length).to eq(10)
    (1..10).each do |i|
      expect(results[i - 1].message).to eq(i)
    end
  end
end
