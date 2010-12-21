
module Castoro #:nodoc:
  module Peer #:nodoc:
    module Version #:nodoc:
      unless defined? MAJOR
        MAJOR  = 0
        MINOR  = 0
        TINY   = 21
        PRE    = nil

        STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')

        PROGRAM_VERSION = "peer-#{STRING} - 2010-12-21"
      end
    end
  end
end

