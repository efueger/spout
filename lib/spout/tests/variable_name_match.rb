# frozen_string_literal: true

module Spout
  module Tests
    module VariableNameMatch
      Dir.glob("variables/**/*.json").each do |file|
        define_method("test_variable_name_match: "+file) do
          assert_equal file.gsub(/^.*\//, "").gsub(".json", "").downcase, (begin JSON.parse(File.read(file, encoding: "utf-8"))["id"] rescue nil end)
        end
      end
    end
  end
end
