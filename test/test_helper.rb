require 'pg_morph'
require 'pry'

require 'minitest/autorun'
require 'minitest/pride'

require File.join(File.dirname(__FILE__), *%w{ .. lib pg_morph })

module PgMorph
  class UnitTest <ActiveSupport::TestCase
  end
end

ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  database: 'pg_morph_test',
  pool: 5,
  username: 'postgres',
  password: 'test123',
  host: 'localhost'
)
