# array_statistics.rb

class Array
  def n
    self.compact.count
  end

  def mean
    array = self.compact
    return nil if array.size == 0
    array.inject(:+).to_f / array.size
  end

  def sample_variance
    array = self.compact
    m = array.mean
    sum = array.inject(0){|accum, i| accum +(i-m)**2 }
    sum / (array.length - 1).to_f
  end

  def standard_deviation
    array = self.compact
    return nil if array.size < 2
    return Math.sqrt(array.sample_variance)
  end

  def median
    array = self.compact.sort
    return nil if array.size == 0
    len = array.size
    len % 2 == 1 ? array[len/2] : (array[len/2 - 1] + array[len/2]).to_f / 2
  end

  def unknown
    self.select{|s| s == nil}.count
  end

  def quartile_sizes
    quartile_size = self.count / 4
    quartile_fraction = self.count % 4

    quartile_sizes = [quartile_size] * 4
    (0..quartile_fraction - 1).to_a.each do |index|
      quartile_sizes[index] += 1
    end

    quartile_sizes
  end

  def quartile_one
    self[0..(self.quartile_sizes[0] - 1)]
  end

  def quartile_two
    sizes = self.quartile_sizes
    start = sizes[0]
    stop = start + sizes[1] - 1
    self[start..stop]
  end

  def quartile_three
    sizes = self.quartile_sizes
    start = sizes[0] + sizes[1]
    stop = start + sizes[2] - 1
    self[start..stop]
  end

  def quartile_four
    sizes = self.quartile_sizes
    start = sizes[0] + sizes[1] + sizes[2]
    stop = start + sizes[3] - 1
    self[start..stop]
  end

  def compact_min
    self.compact.min
  end

  def compact_max
    self.compact.max
  end

end

module Spout
  module Helpers
    class ArrayStatistics
      def self.calculations
        [["N", :n, :count], ["Mean", :mean, :decimal], ["StdDev", :standard_deviation, :decimal, "± %s"], ["Median", :median, :decimal], ["Min", :compact_min, :decimal], ["Max", :compact_max, :decimal], ["Unknown", :unknown, :count]]
      end
    end
  end
end