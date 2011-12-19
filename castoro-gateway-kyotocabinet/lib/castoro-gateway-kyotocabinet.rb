
require "rubygems"
gem "castoro-gateway", ">=0.2.0.pre"
require "castoro-gateway"

module Castoro
  class Cache
    autoload :KyotoCabinet, 'castoro-gateway-kyotocabinet/kyotocabinet'
  end
end

