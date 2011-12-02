
require "rubygems"
require "castoro-gateway"

module Castoro
  class Cache
    autoload :KyotoCabinet, 'castoro-gateway-kyotocabinet/kyotocabinet'
  end
end

