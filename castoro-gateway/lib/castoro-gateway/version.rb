
module Castoro #:nodoc:
  class Gateway #:nodoc:
    module Version #:nodoc:
      unless defined? MAJOR
        MAJOR  = 0
        MINOR  = 2
        TINY   = 0
        PRE    = 'pre20111219'

        STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
      end
    end
  end
end

