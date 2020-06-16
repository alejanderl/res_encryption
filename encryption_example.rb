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

class EncryptionKeyRepository
  DEFAULT_CIPHER = 'aes-256-cbc'.freeze

  def initialize
    @keys = {}
  end

  def key_of(identifier, cipher: DEFAULT_CIPHER)
    @keys[[identifier, cipher]] || create(identifier)
  end

  def create(identifier, cipher: DEFAULT_CIPHER)
    @keys[[identifier, cipher]] = RubyEventStore::Mappers::EncryptionKey.new(
      cipher: cipher,
      key: random_key(cipher)
    )
  end

  def forget(identifier)
    @keys = @keys.reject { |(id, _)| id.eql?(identifier) }
  end

  private
  def random_key(cipher)
    crypto = OpenSSL::Cipher.new(cipher)
    crypto.encrypt
    crypto.random_key
  end
end

class MyEvent < RubyEventStore::Event
  SCHEMA = Types::Hash.schema(
    id: Types::Strict::String,
    email: Types::Strict::String.maybe,
    username: Types::Strict::String.optional,
    password: Types::Strict::String
  )

  class << self
    def strict(data: nil, metadata: nil)
      data = SCHEMA.(data)
      new(data: resolve_monads!(data), metadata: metadata)
    end

    def resolve_monads!(dry_attributes)
      hash_checker = ->(checkable) do
        return resolve_value(checkable) unless checkable.is_a?(Hash)

        checkable.each do |k, v|
          next checkable.delete(k) if v.is_a?(Dry::Monads::Maybe::None)

          checkable[k] = resolve_value(v)
        end
      end

      hash_checker.call(dry_attributes)
    end

    def resolve_value(value)
      value.is_a?(Dry::Monads::Maybe::Some) ? value.value! : value
    end

    def encryption_schema
      {
        email: ->(data) { data.fetch(:id) },
        username: ->(data) { data.fetch(:id) },
        password: ->(data) { data.fetch(:id) }
      }
    end
  end
end

RSpec.describe "An event with maybe keys" do
  let(:key_repository) do
    EncryptionKeyRepository.new
  end

  let(:store) do
    RubyEventStore::InMemoryRepository.new
  end

  let(:mapper) do
    RubyEventStore::Mappers::EncryptionMapper.new(
      key_repository,
      serializer: YAML
    )
  end

  let(:res_client) do
    RubyEventStore::Client.new(
      repository: store,
      mapper: mapper
    )
  end

  subject do
    res_client.publish MyEvent.strict(data: data)
  end

  let(:id) { SecureRandom.uuid }
  let(:email) { "asdads@example.com" }
  let(:username) { "johnny" }
  let(:password) { "supersecret" }
  let(:data) do
    {
      id: id,
      email: email,
      username: username,
      password: password
    }
  end

  context "when email is present" do
    it "publishes the event" do
      subject

      data = res_client.read.last.data
      expect(data[:id]).to eq(id)
      expect(data[:email]).to eq(email)
      expect(data[:username]).to eq(username)
      expect(data[:password]).to eq(password)
    end
  end

  context "when email is nil" do
    let(:email) { nil }

    it "publishes the event" do
      subject

      data = res_client.read.last.data
      expect(data[:id]).to eq(id)
      expect(data[:email]).to eq(nil)
      expect(data[:username]).to eq(username)
      expect(data[:password]).to eq(password)
    end
  end

  context "when email is not present" do
    let(:data) do
      {
        id: id,
        username: username,
        password: password
      }
    end

    it "publishes the event" do
      subject

      data = res_client.read.last.data
      expect(data[:id]).to eq(id)
      expect(data[:email]).to eq(nil)
      expect(data[:username]).to eq(username)
      expect(data[:password]).to eq(password)
    end
  end
end
