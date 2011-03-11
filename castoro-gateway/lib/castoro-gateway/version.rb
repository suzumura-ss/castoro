
module Castoro #:nodoc:
  class Gateway #:nodoc:
    module Version #:nodoc:
      unless defined? MAJOR
        MAJOR  = 0
        MINOR  = 0
        TINY   = 15
        PRE    = nil

        STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
      end
    end
  end
end

