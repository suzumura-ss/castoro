
module Castoro #:nodoc:
  class Gateway #:nodoc:
    module Version #:nodoc:
      unless defined? MAJOR
        MAJOR  = 1
        MINOR  = 1
        TINY   = 1
        PRE    = nil

        STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
      end
    end
  end
end

