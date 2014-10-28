
# require 'spout/models/dictionary' # Includes forms, variables, and domains
require 'spout/models/variable'
require 'spout/models/bucket'
require 'spout/helpers/array_statistics'

module Spout
  module Models
    class Graph

      attr_accessor :chart_variable, :subjects, :variable, :stratification_variable

      def initialize(chart_type, subjects, variable, stratification_variable)
        @chart_variable = Spout::Models::Variable.find_by_id(chart_type)
        @subjects = subjects
        @variable = variable # Spout::Models::Variable
        @stratification_variable = stratification_variable # This should be Spout::Models::Variable
        @values = subjects.collect(&@variable.id.to_sym).uniq rescue @values = []
        @values_unique = @values.uniq

        @buckets = continuous_buckets
      end

      # Public methods

      def to_hash
        if @values == [] or @variable == nil or @chart_variable == nil
          nil
        elsif @variable.type == 'choices' and @variable.domain.options == []
          nil
        elsif @chart_variable == nil
          nil
        elsif @chart_variable and @chart_variable.type == 'choices' and @chart_variable.domain.options == []
          nil
        else
          { title: title, subtitle: subtitle, categories: categories, units: units, series: series, stacking: stacking, x_axis_title: x_axis_title }
        end
      end

      def title
        if histogram?
          @variable.display_name
        else
          "#{@variable.display_name} by #{@chart_variable.display_name}"
        end
      end

      def subtitle
        "By Visit"
      end

      def categories
        @categories ||= begin
          categories_result = []
          if histogram?
            if @variable.type == 'choices'
              categories_result = filtered_domain_options(@variable).collect(&:display_name)
            else
              categories_result = @buckets.collect(&:display_name)
            end
          elsif numeric_versus_choices?
            # chart_arbitrary
            @stratification_variable.domain.options.each do |option|
              visit_subjects = @subjects.select{ |s| s._visit == option.value and s.send(@variable.id) != nil } rescue visit_subjects = []
              if visit_subjects.count > 0
                categories_result << option.display_name
              end
            end
          elsif choices_versus_choices?
            categories_result = filtered_domain_options(@chart_variable).collect(&:display_name)
          elsif numeric_versus_numeric?
            categories_result = ["Quartile One", "Quartile Two", "Quartile Three", "Quartile Four"]
          elsif choices_versus_numeric?
            filtered_subjects = @subjects.select{ |s| s.send(@variable.id) != nil and s.send(@chart_variable.id) != nil }.sort_by(&@chart_variable.id.to_sym) rescue filtered_subjects = []

            categories_result = [:quartile_one, :quartile_two, :quartile_three, :quartile_four].collect do |quartile|
              quartile = filtered_subjects.send(quartile).collect(&@chart_variable.id.to_sym)
              "#{quartile.min} to #{quartile.max}"
            end
          else
            # Other Graph Types
          end

          categories_result
        end
      end

      def units
        units_result = ''
        if histogram?
          units_result = 'Subjects'
        elsif numeric_versus_choices?
          units_result = @variable.units
        elsif choices_versus_choices?
          units_result = 'percent'
        elsif numeric_versus_numeric?
          units_result = @variable.units
        elsif choices_versus_numeric?
          units_result = 'percent'
        else

        end

        units_result
      end

      def series
        series_result = []
        if histogram?
          @chart_variable.domain.options.each do |option|
            visit_subjects = @subjects.select{ |s| s.send(@chart_variable.id) == option.value and s.send(@variable.id) != nil } rescue visit_subjects = []
            visit_subject_values = visit_subjects.collect(&@variable.id.to_sym).sort rescue visit_subject_values = []
            next unless visit_subject_values.size > 0

            data = []

            if @variable.type == 'choices'
              data = filtered_domain_options(@variable).collect do |option|
                visit_subject_values.select{ |v| v == option.value }.count
              end
            else
              visit_subject_values.group_by{|v| get_bucket(v) }.each do |key, values|
                data[categories.index(key)] = values.count if categories.index(key)
              end
            end

            series_result << { name: option.display_name, data: data }

          end
        elsif numeric_versus_choices?
          data = []

          @stratification_variable.domain.options.each do |option|
            visit_subjects = @subjects.select{ |s| s._visit == option.value and s.send(@variable.id) != nil } rescue visit_subjects = []
            if visit_subjects.count > 0

              filtered_domain_options(@chart_variable).each_with_index do |option, index| ###
                values = visit_subjects.select{|s| s.send(@chart_variable.id) == option.value }.collect(&@variable.id.to_sym)
                data[index] ||= []
                data[index] << (values.mean.round(2) rescue 0.0)
              end

            end
          end

          filtered_domain_options(@chart_variable).each_with_index do |option, index|
             series_result << { name: option.display_name, data: data[index] }
          end
        elsif choices_versus_choices?
          series_result = filtered_domain_options(@variable).collect do |option|
            filtered_subjects = @subjects.select{ |s| s.send(@variable.id) == option.value }
            data = filtered_domain_options(@chart_variable).collect do |chart_option|
              filtered_subjects.select{ |s| s.send(@chart_variable.id) == chart_option.value }.count
            end
            { name: option.display_name, data: data }
          end
        elsif numeric_versus_numeric?

           @stratification_variable.domain.options.each do |option|
            data = []

            filtered_subjects = @subjects.select{ |s| s._visit == option.value and s.send(@variable.id) != nil and s.send(@chart_variable.id) != nil }.sort_by(&@chart_variable.id.to_sym) rescue filtered_subjects = []

            [:quartile_one, :quartile_two, :quartile_three, :quartile_four].each do |quartile|
              array = filtered_subjects.send(quartile).collect(&@variable.id.to_sym)
              data << {         y: (array.mean.round(1) rescue 0.0),
                           stddev: ("%0.1f" % array.standard_deviation rescue ''),
                           median: ("%0.1f" % array.median rescue ''),
                              min: ("%0.1f" % array.min rescue ''),
                              max: ("%0.1f" % array.max rescue ''),
                                n: array.n }
            end

            series_result << { name: option.display_name, data: data } unless filtered_subjects.size == 0
          end
        elsif choices_versus_numeric?
          filtered_subjects = @subjects.select{ |s| s.send(@variable.id) != nil and s.send(@chart_variable.id) != nil }.sort_by(&@chart_variable.id.to_sym) rescue filtered_subjects = []

          filtered_domain_options(@variable).each do |option|
            data = [:quartile_one, :quartile_two, :quartile_three, :quartile_four].collect do |quartile|
              filtered_subjects.send(quartile).select{ |s| s.send(@variable.id) == option.value }.count
            end
            series_result << { name: option.display_name, data: data } unless filtered_subjects.size == 0
          end
        else

        end
        series_result
      end

      def stacking
        stacking_result = nil

        if histogram?
          # chart_histogram
        elsif numeric_versus_choices?
          # chart_arbitrary
        elsif choices_versus_choices?
          # chart_arbitrary_choices
          stacking_result = 'percent'
        elsif numeric_versus_numeric?
          # chart_arbitrary_by_quartile
        elsif choices_versus_numeric?
          # chart_arbitrary_choices_by_quartile
          stacking_result = 'percent'
        else

        end

        stacking_result
      end

      def x_axis_title
        x_axis_title_result = nil
        if histogram?
          x_axis_title_result = @variable.units
        elsif numeric_versus_choices?
          # chart_arbitrary
        elsif choices_versus_choices?
          # chart_arbitrary_choices
        elsif numeric_versus_numeric?
          # chart_arbitrary_by_quartile
        elsif choices_versus_numeric?
          # chart_arbitrary_choices_by_quartile
        else

        end

        x_axis_title_result
      end

      private

      def histogram?
        @stratification_variable == nil
      end

      def numeric_versus_choices?
        ['numeric', 'integer'].include?(@variable.type) and @chart_variable.type == 'choices'
      end

      def choices_versus_choices?
        @variable.type == 'choices' and @chart_variable.type == 'choices'
      end

      def numeric_versus_numeric?
        ['numeric', 'integer'].include?(@variable.type) and ['numeric', 'integer'].include?(@chart_variable.type)
      end

      def choices_versus_numeric?
        @variable.type == 'choices' and ['numeric', 'integer'].include?(@chart_variable.type)
      end

      def continuous_buckets
        values_numeric = @values.select{|v| v.kind_of? Numeric}
        return [] if values_numeric.count == 0
        minimum_bucket = values_numeric.min
        maximum_bucket = values_numeric.max
        max_buckets = 12
        bucket_size = ((maximum_bucket - minimum_bucket) / max_buckets.to_f)
        precision = (bucket_size == 0 ? 0 : [-Math.log10(bucket_size).floor, 0].max)

        buckets = []
        (0..(max_buckets-1)).to_a.each do |index|
          start = (minimum_bucket + index * bucket_size)
          stop = (start + bucket_size)
          buckets << Spout::Models::Bucket.new(start.round(precision),stop.round(precision))
        end
        buckets
      end

      def get_bucket(value)
        return nil if @buckets.size == 0 or not value.kind_of?(Numeric)
        @buckets.each do |b|
          return b.display_name if b.in_bucket?(value)
        end
        if value <= @buckets.first.start
          @buckets.first.display_name
        else
          @buckets.last.display_name
        end
      end

      # Returns variable options that are either:
      # a) are not missing codes
      # b) or are marked as missing codes but represented in the dataset
      def filtered_domain_options(variable)
        variable.domain.options.select do |o|
          o.missing != true or (o.missing == true and @values_unique.include?(o.value))
        end
      end

    end
  end
end
