
module Castoro #:nodoc:
  module Manipulator #:nodoc:
    module Version #:nodoc:
      unless defined? MAJOR
        MAJOR  = 0
        MINOR  = 2
        TINY   = 0
        PRE    = 'pre'

        STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
      end
    end
  end
end

