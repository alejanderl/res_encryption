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
  gem "byebug"
  gem 'dry-monads'

end

require "ruby_event_store"
require 'time'
require 'json'
require 'byebug'
require 'dry-struct'
require 'dry-types'
require 'dry/monads'

Dry::Types.load_extensions(:maybe)
module Types
  include Dry::Types()
end

class MyEvent < RubyEventStore::Event

  SCHEMA = Types::Hash.schema(
    email: Types::Strict::String.maybe
  )

  def self.strict(data: nil, metadata: nil)
    data = SCHEMA.(data)
    new(data: data, metadata: metadata)
  end

  def self.encryption_schema
    {
      email: ->(data) { SecureRandom.uuid }
    }
  end
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
    res_client.publish MyEvent.strict(data: {email: "asdads"})
  end
end