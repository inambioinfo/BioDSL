# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< #
#                                                                              #
# Copyright (C) 2007-2015 Martin Asser Hansen (mail@maasha.dk).                #
#                                                                              #
# This program is free software; you can redistribute it and/or                #
# modify it under the terms of the GNU General Public License                  #
# as published by the Free Software Foundation; either version 2               #
# of the License, or (at your option) any later version.                       #
#                                                                              #
# This program is distributed in the hope that it will be useful,              #
# but WITHOUT ANY WARRANTY; without even the implied warranty of               #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                #
# GNU General Public License for more details.                                 #
#                                                                              #
# You should have received a copy of the GNU General Public License            #
# along with this program; if not, write to the Free Software                  #
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,    #
# USA.                                                                         #
#                                                                              #
# http://www.gnu.org/copyleft/gpl.html                                         #
#                                                                              #
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< #
#                                                                              #
# This software is part of the Biopieces framework (www.biopieces.org).        #
#                                                                              #
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< #

module BioPieces
  # == Grab records in stream.
  #
  # +grab+ select records from the stream by matching patterns to keys or
  # values. +grab+ is  Biopieces' equivalent of Unix' +grep+, however, +grab+
  # is much more versatile.
  #
  # NB! If chaining multiple +grab+ commands then use the most restrictive
  # +grab+ first in order to get the best performance.
  #
  # == Usage
  #
  #    grab(<select: <pattern>|select_file: <file>|reject: <pattern>|
  #                reject_file: <file>|evaluate: <expression>|exact: <bool>>
  #               [, keys: <list>|keys_only: <bool>|values_only: <bool>|
  #               ignore_case: <bool>])
  #
  # === Options
  #
  # * select: <pattern>      - Select records matching <pattern> which is
  #   a regex or an exact match if the exact option is set.
  # * select_file: <file>    - File with one <pattern> per line to select.
  # * reject: <pattern>      - Reject records matching <pattern> which is
  #   a regex or an exact match if the exact option is set.
  # * reject_file: <file>    - File with one <pattern> per line to reject.
  # * evaluate: <expression> - Select records where <expression> is true.
  # * exact: <bool>          - Turn on exact matching for improved speed.
  # * keys: <list>           - Comma separated list or array of keys to grab
  #   the value for.
  # * keys_only: <bool>      - Only grab for keys.
  # * values_only: <bool>    - Only grab for values.
  # * ignore_case: <bool>    - Ignore case when grabbing with regex (does not
  #   work with +evaluate+ and +exact+).
  #
  # == Examples
  #
  # To easily grab all records in the stream that has any mentioning of the
  # pattern 'human' just pipe the data stream through grab like this:
  #
  #    grab(select: "human")
  #
  # This will search for the pattern 'human' in all keys and all values. The
  # +select+ option alternatively uses an array of patterns, so in order to
  # match one of multiple patterns do:
  #
  #    grab(select: ["human", "mouse"])
  #
  # It is also possible to invoke flexible matching using regex (regular
  # expressions) instead of simple pattern matching. If you want to +grab+
  # records with the sequence +ATCG+ or +GCTA+ you can do this:
  #
  #    grab(select: "ATCG|GCTA")
  #
  # Or if you want to +grab+ sequences beginning with +ATCG+:
  #
  #    grab(select: "^ATCG")
  #
  # It is also possible to use the +select_file+ option to load patterns from
  # a file with one pattern per line.
  #
  #    grab(select_file: "patterns.txt")
  #
  # If you want the opposite result - to find all records that does not match
  # the a pattern, use the +reject+ option:
  #
  #    grab(reject: "human")
  #
  # Similar to +select_file+ there is a +reject_file+ option to load patterns
  # from a file, and use any of these patterns to reject records:
  #
  #    grab(reject_file: "patterns.txt")
  #
  # If you want to search the record keys only, e.g. to +grab+ all records
  # containing the key +SEQ+ you can use the +keys_only+ option. This will
  # prevent matching of +SEQ+ in any record value, and in fact +SEQ+ is a not
  # uncommon peptide sequence you could get an unwanted record. Also, this
  # will give an increase in speed since only the keys are searched:
  #
  #    grab(select: "SEQ", keys_only: true)
  #
  # However, if you are interested in +grabbing+ the peptide sequence +SEQ+ and
  # not the +SEQ+ key, just use the +vals_only+ option:
  #
  #    grab(select: "SEQ", vals_only: true)
  #
  # Also, if you want to +grab+ for certain key/value pairs you can supply a
  # comma separated list or an array of keys whos values will then be grabbed
  # using the +keys+ option. This is handy if your records contain large
  # genomic sequences and you don't want to search the entire sequence for
  # e.g. the organism name - it is much faster to tell +grab+ which keys to
  # search the value for:
  #
  #    grab(select: "human", keys: :SEQ_NAME)
  #
  # You can also use the +evaluate+ option to +grab+ records that fulfill an
  # expression. So to +grab+ all records with a sequence length greater than 30:
  #
  #    grab(evaluate: 'SEQ_LEN > 30')
  #
  # If you want to +grab+ all records containing the pattern 'human' and where
  # the sequence length is greater that 30, you do this by running the stream
  # through +grab+ twice:
  #
  #    grab(select: 'human').grab(evaluate: 'SEQ_LEN > 30')
  #
  # Finally, it is possible to +grab+ for exact pattern using the +exact+
  # option. This is much faster than the default regex pattern grabbing
  # because with +exact+ the patterns are used to create a lookup hash for
  # instant matching of keys or values. This is useful if you e.g. have a
  # file with ID numbers and you want to +grab+ matching records from the
  # stream:
  #
  #    grab(select_file: "ids.txt", keys: :ID, exact: true)
  #
  # rubocop:disable ClassLength
  class Grab
    require 'biopieces/helpers/options_helper'
    require 'biopieces/helpers/status_helper'

    extend OptionsHelper
    include OptionsHelper
    include StatusHelper

    # Check the options and return a lambda for the command.
    #
    # @param [Hash] options Options hash.
    #
    # @option options [String, Array] :select
    #   Patterns or list of patterns to select records.
    #
    # @option options [String] :select_file
    #   File path with patterns, one per line, to select records.
    #
    # @option options [String, Array] :reject
    #   Patterns or list of patterns to reject records.
    #
    # @option options [String] :reject_file
    #   File path with patterns, one per line, to reject records.
    #
    # @option options [String] :evaluate
    #   Expression that is evaluated to select records.
    #
    # @option options [Boolean] :exact
    #   Flag indicating that a given pattern must match over its entire length.
    #
    # @option options [Symbol, Array] :keys
    #   Key or list of keys whos key/value pairs to grab for.
    #
    # @option options [Boolean] :keys_only
    #   Flag indicating to grab for key only - not values.
    #
    # @option options [Boolean] :values_only
    #   Flag indicating to grab for values only - not keys.
    #
    # @option options [Boolean] :ignore_case
    #   Flag indicating that pattern matching should be case insensitive.
    #
    # @return [Proc] Returns the command lambda.
    def self.lmb(options)
      options_allowed(options, :select, :select_file, :reject, :reject_file,
                      :evaluate, :exact, :keys, :keys_only, :values_only,
                      :ignore_case)
      options_required_unique(options, :select, :select_file, :reject,
                              :reject_file, :evaluate)
      options_conflict(options, keys: :evaluate, keys_only: :evaluate,
                                values_only: :evaluate, ignore_case: :evaluate,
                                exact: :evaluate)
      options_unique(options, :keys_only, :values_only)
      options_files_exist(options, :select_file, :reject_file)

      new(options).lmb
    end

    # Constructor for the ReadFasta class.
    #
    # @param [Hash] options Options hash.
    #
    # @option options [String, Array] :select
    #   Patterns or list of patterns to select records.
    #
    # @option options [String] :select_file
    #   File path with patterns, one per line, to select records.
    #
    # @option options [String, Array] :reject
    #   Patterns or list of patterns to reject records.
    #
    # @option options [String] :reject_file
    #   File path with patterns, one per line, to reject records.
    #
    # @option options [String] :evaluate
    #   Expression that is evaluated to select records.
    #
    # @option options [Boolean] :exact
    #   Flag indicating that a given pattern must match over its entire length.
    #
    # @option options [Symbol, Array] :keys
    #   Key or list of keys whos key/value pairs to grab for.
    #
    # @option options [Boolean] :keys_only
    #   Flag indicating to grab for key only - not values.
    #
    # @option options [Boolean] :values_only
    #   Flag indicating to grab for values only - not keys.
    #
    # @option options [Boolean] :ignore_case
    #   Flag indicating that pattern matching should be case insensitive.
    #
    # @return [ReadFasta] Returns an instance of the class.
    def initialize(options)
      @options   = options
      @keys_only = @options[:keys_only]
      @vals_only = @options[:values_only]
      @invert    = @options[:reject] || @options[:reject_file]
      @patterns  = compile_patterns
      @keys      = compile_keys
      @exact     = compile_exact
      @regex     = compile_regexes
      @eval      = @options[:evaluate]
      status_init(:records_in, :records_out)
    end

    # Return a lambda for the grab command.
    #
    # @return [Proc] Returns the grab command lambda.
    def lmb
      lambda do |input, output, status|
        input.each do |record|
          @records_in += 1

          match = case
                  when @exact then exact_match? record
                  when @regex then regex_match? record
                  when @eval  then eval_match? record
                  end

          emit_match(output, record, match)
        end

        status_assign(status, :records_in, :records_out)
      end
    end

    private

    # Emit a record to the output stream if a match was found and w/o invert
    # matching, or if no match was found and with invert matching.
    #
    # @param output [Enumerator::Yielder] Output stream.
    # @param record [Hash] Record to emit.
    # @param match  [Boolean] Flag indicating a positive match.
    def emit_match(output, record, match)
      if match && !@invert
        output << record
        @records_out += 1
      elsif !match && @invert
        output << record
        @records_out += 1
      end
    end

    # Compile a list of keys from the options hash, which may contain either a
    # list of keys, a symbol or a comma seperated string of keys.
    #
    # @return [Array] List of keys (Symbols).
    def compile_keys
      return unless @options[:keys]

      case @options[:keys].class.to_s
      when 'Array'
        @options[:keys].map(&:to_sym)
      when 'Symbol'
        [@options[:keys]]
      when 'String'
        @options[:keys].split(/, */).map { |key| key.sub(/^:/, '').to_sym }
      end
    end

    # Compile a list of patterns to select or reject.
    #
    # @return [Array] List of patterns.
    def compile_patterns
      case
      when @options[:select]      then compile_patterns_select
      when @options[:select_file] then compile_patterns_select_file
      when @options[:reject]      then compile_patterns_reject
      when @options[:reject_file] then compile_patterns_reject_file
      end
    end

    # Compile a list of patterns to select from an Array, a String, an Integer
    # or a Float.
    #
    # @return [Array] List of patterns.
    def compile_patterns_select
      if @options[:select].class == Array
        @options[:select]
      else
        [@options[:select]]
      end
    end

    # Compile a list of patterns to select from a file with one pattern per
    # line.
    #
    # @return [Array] List of patterns.
    def compile_patterns_select_file
      patterns = []

      File.open(@options[:select_file]) do |ios|
        ios.each_line { |line| patterns << line.chomp.to_num }
      end

      patterns
    end

    # Compile a list of patterns to reject from an Array, a String, an Integer
    # or a Float.
    #
    # @return [Array] List of patterns.
    def compile_patterns_reject
      if @options[:reject].is_a? Array
        @options[:reject]
      else
        [@options[:reject]]
      end
    end

    # Compile a list of patterns to reject from a file with one pattern per
    # line.
    #
    # @return [Array] List of patterns.
    def compile_patterns_reject_file
      patterns = []

      File.open(@options[:reject_file]) do |ios|
        ios.each_line { |line| patterns << line.chomp.to_num }
      end

      patterns
    end

    # Compile a list of regexes for matching.
    #
    # @return [Array] List of regexes.
    def compile_regexes
      return if     @exact
      return unless @patterns

      if @options[:ignore_case]
        @patterns.inject([]) { |a, e| a << Regexp.new(/#{e}/i) }
      else
        @patterns.inject([]) { |a, e| a << Regexp.new(/#{e}/) }
      end
    end

    # Compile a lookup set for fast exact matching.
    #
    # @return [Set] Set of exact patterns.
    def compile_exact
      require 'set'

      return unless @options[:exact]

      lookup = Set.new

      @patterns.each do |pattern|
        if pattern.is_a?(Float) || pattern.is_a?(Integer)
          lookup << pattern
        else
          lookup << pattern.to_sym
        end
      end

      lookup
    end

    # Match exactly record keys or values
    #
    # @param record [Hash] Record to match.
    #
    # @return [Boolean] True if exact match found.
    def exact_match?(record)
      keys = @keys || record.keys

      if @keys_only
        exact_match_keys?(keys)
      elsif @vals_only
        exact_match_values?(record, keys)
      else
        exact_match_key_values?(record, keys)
      end
    end

    # Match exactly any record keys.
    #
    # @param keys [Array] List of keys to match.
    #
    # @return [Boolean] True if exact match found.
    def exact_match_keys?(keys)
      keys.each do |key|
        return true if @exact.include?(key)
      end

      false
    end

    # Match exactly any record values.
    #
    # @param record [Hash] Record to match.
    # @param keys [Array] List of keys whos values to match.
    #
    # @return [Boolean] True if exact match found.
    def exact_match_values?(record, keys)
      keys.each do |key|
        if (value = record[key])
          return true if value.is_a?(String)  && @exact.include?(value.to_sym)
          return true if !value.is_a?(String) && @exact.include?(value)
        end
      end

      false
    end

    # Match exactly any record keys or values.
    #
    # @param record [Hash] Record to match.
    # @param keys [Array] List of keys or values to match.
    #
    # @return [Boolean] True if exact match found.
    def exact_match_key_values?(record, keys)
      keys.each do |key|
        return true if @exact.include?(key)

        next unless record[key]
        value = record[key]

        if @exact.include?(value.respond_to?(:to_sym) ? value.to_sym : value)
          return true
        end
      end

      false
    end

    def regex_match?(record)
      keys = @keys || record.keys

      if @keys_only
        regex_match_keys?(keys)
      elsif @vals_only
        regex_match_values?(record, keys)
      else
        regex_match_key_values?(record, keys)
      end
    end

    # Match using regex any record keys.
    #
    # @param keys [Array] List of keys to match.
    #
    # @return [Boolean] True if regex match found.
    def regex_match_keys?(keys)
      keys.each do |key|
        @regex.each do |regex|
          return true if key.to_s =~ regex
        end
      end

      false
    end

    # Match using regex any record values.
    #
    # @param record [Hash] Record to match.
    # @param keys [Array] List of keys whos values to match.
    #
    # @return [Boolean] True if regex match found.
    def regex_match_values?(record, keys)
      keys.each do |key|
        next unless record[key]
        value = record[key]

        @regex.each do |regex|
          return true if value.to_s =~ regex
        end
      end

      false
    end

    # Match using regex any record keys or values.
    #
    # @param record [Hash] Record to match.
    # @param keys [Array] List of keys or values to match.
    #
    # @return [Boolean] True if regex match found.
    def regex_match_key_values?(record, keys)
      keys.each do |key|
        @regex.each do |regex|
          return true if key.to_s =~ regex
        end

        next unless record[key]
        value = record[key]

        @regex.each do |regex|
          return true if value.to_s =~ regex
        end
      end

      false
    end

    # Match using eval expression on record values.
    #
    # @param record [Hash] Record to match.
    #
    # @return [Boolean] True if eval match found.
    def eval_match?(record)
      expr = []

      @eval.split("\s").each do |item|
        if item[0] == ':'
          key = item[1..-1].to_sym

          return false unless record[key]

          expr << record[key]
        else
          expr << item
        end
      end

      eval expr.join(' ')
    end
  end
end
