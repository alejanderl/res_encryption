begin
  require "bundler/inline"
rescue LoadError => e
  $stderr.puts "Bundler version 1.10 or later is required. Please update your Bundler"
  raise e
end

gemfile(true) do
  source "https://rubygems.org"

  gem 'ruby_event_store', '~> 1.0.0'
  gem 'dry-struct'
  gem 'dry-types'
  gem 'rspec'
  gem "pry"

end

require "ruby_event_store"
require 'time'
require 'json'
require 'pry'
require 'dry-struct'
require 'dry-types'

class MyEvent < RubyEventStore::Event
end


RSpec.describe "Make this thing work" do

  let(:store) { RubyEventStore::InMemoryRepository.new }

  let(:res_client) do
    RubyEventStore::Client.new(
      repository: store,
      mapper: RubyEventStore::Mappers::EncryptionMapper.new(
        RubyEventStore::Mappers::InMemoryEncryptionKeyRepository.new,
        serializer: YAML
      )
    )
  end

  it "works" do
    binding.pry
  end
end