$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "crypto_gost3411"

require "minitest/autorun"
require "minitest/reporters"
Minitest::Reporters.use!
