module Spout
  module VERSION #:nodoc:
    MAJOR = 0
    MINOR = 3
    TINY = 0
    BUILD = "rc2" # nil, "pre", "rc", "rc2"

    STRING = [MAJOR, MINOR, TINY, BUILD].compact.join('.')
  end
end
