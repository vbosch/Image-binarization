require 'logger'
require 'singleton'

module Utils
  class ApplicationLogger < Logger
    include Singleton
    
    def initialize
      
      super(STDOUT)
      
    end
    
  end
end