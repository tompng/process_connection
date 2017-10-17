$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "process_connection"
require "minitest/autorun"

class ProcessConnectionTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::ProcessConnection::VERSION
  end

  def test_fork
    result = `bundle exec ruby #{File.expand_path 'fork.rb', __dir__}`
    expected = [
      'AaBaCa', # broadcast
      3, # response: false
      'AcBc', # include_self: false
      2, # response: false, include_self: false
      'AeBeCe', # broadcast
      'pong', 'pong',
      # process D start
      'AaBaCaDa', # broadcast
      4, # response: false
      'AcBcDc', # include_self: false
      3, # response: false, include_self: false
      'AeBeCeDe', # broadcast
      'pong', 'pong', 'pong',
      # process D end
      'AaBaCa', # broadcast
      3, # response: false
      'AcBc', # include_self: false
      2, # response: false, include_self: false
      'AeBeCe', # broadcast
      'pong', 'pong'
    ]
    puts expected.join("\n")+"\n"
    puts '---'
    puts result
    assert result == expected.join("\n")+"\n"
  end
end
