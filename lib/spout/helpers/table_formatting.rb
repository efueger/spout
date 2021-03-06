# frozen_string_literal: true

require "spout/helpers/number_helper"

module Spout
  module Helpers
    # Formats numbers in coverage and outlier tables.
    class TableFormatting
      # def initialize(number)
      #   @number = number
      # end

      # type:  :count    or   :decimal
      def self.format_number(number, type, format = nil)
        if number.nil?
          format_nil
        elsif type == :count
          format_count(number)
        else
          format_decimal(number, format)
        end
      end

      def self.format_nil
        "-"
      end

      #   count:
      #        0          ->             "-"
      #       10          ->            "10"
      #     1000          ->         "1,000"
      # Input (Numeric)   -> Output (String)
      def self.format_count(number)
        number.zero? || number.nil? ? "-" : Spout::Helpers::NumberHelper.number_with_delimiter(number)
      end

      # decimal:
      #        0          ->           "0.0"
      #       10          ->          "10.0"
      #      -50.2555     ->         "-50.3"
      #     1000          ->       "1,000.0"
      # 12412423.42252525 ->  "12,412,423.4"
      # Input (Numeric)   -> Output (String)
      def self.format_decimal(number, format)
        precision = 1
        precision = -Math.log10(number.abs).floor if number.abs < 1.0 && !number.zero?

        number = Spout::Helpers::NumberHelper.number_with_delimiter(number.to_f.round(precision))
        number = format % number if format
        number
      end
    end
  end
end
