$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

# No, Buffet does not use Buffet to run its own test cases. That would be silly.

require 'buffet/status_message'
