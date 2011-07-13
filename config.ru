$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__)) + "/lib")
require 'buffet/frontend'
run Buffet::Frontend
