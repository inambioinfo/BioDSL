# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< #
#                                                                                #
# Copyright (C) 2007-2014 Martin Asser Hansen (mail@maasha.dk).                  #
#                                                                                #
# This program is free software; you can redistribute it and/or                  #
# modify it under the terms of the GNU General Public License                    #
# as published by the Free Software Foundation; either version 2                 #
# of the License, or (at your option) any later version.                         #
#                                                                                #
# This program is distributed in the hope that it will be useful,                #
# but WITHOUT ANY WARRANTY; without even the implied warranty of                 #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                  #
# GNU General Public License for more details.                                   #
#                                                                                #
# You should have received a copy of the GNU General Public License              #
# along with this program; if not, write to the Free Software                    #
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA. #
#                                                                                #
# http://www.gnu.org/copyleft/gpl.html                                           #
#                                                                                #
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< #
#                                                                                #
# This software is part of Biopieces (www.biopieces.org).                        #
#                                                                                #
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< #

class Array
  # Method that converts variable types given an array of types.
  # Example: ["fish", 0.0, 1].convert_types([:to_s, :to_f, :to_i])
  def convert_types(types)
    raise ArgumentError, "Array and types size mismatch: #{self.size} != #{types.size}" if self.size != types.size

    types.each_with_index do |type, i|
      self[i] = self[i].send(type)
    end

    self
  end
end

module BioPieces
  class CSVError < StandardError; end

  # Class for manipulating CSV or table files.
  # Allow reading and writing of gzip and bzip2 data.
  # Auto-convert data types.
  # Returns lines, arrays or hashes.
  class CSV
    def self.open(*args)
      io = IO.open(*args)

      if block_given?
        yield self.new(io)
      else
        return self.new(io)
      end
    end

    # Method that reads all CSV data from a file into an array of arrays (array
    # of rows) which is returned. Using the option[:header] parses any single
    # header line prefixed with '#'.
    def self.read(file, options = {})
      data = []

      self.open(file) do |ios|
        if options[:include_header]
          data << ios.header.map { |h| h.to_s }
        end

        ios.each_array { |row| data << row } 
      end

      data
    end

    def initialize(io)
      @io        = io
      @delimiter = "\s"
      @header    = nil
    end

    # Method to return a table header prefixed with '#'. If a header was
    # already located it is returned, otherwise only the first 10 lines
    # are examined and if no header is found nil is returned. If header is
    # found it is returned as an array.
    #
    #   CSV.header(options={}) -> Array
    #
    # Options:
    #   * :delimiter - specify an alternative field delimiter (default="\s").
    #   * :columns   - specify a list or range of header columns to return.
    def header(options = {})
      return @header if @header

      delimiter = options[:delimiter] || @delimiter
      columns   = options[:columns]

      @io.each_with_index do |line, i|
        line.chomp!
        next if line.empty?

        if line[0] == '#'
          fields = line[1 .. -1].split(delimiter)

          if columns and columns.max >= fields.size
            raise CSVError, "Requested columns out of bounds: #{columns.select { |c| c >= fields.size }}"
          end

          if columns
            @header = fields.values_at(*columns).map { |h| h.to_sym }
          else
            @header = fields.map { |h| h.to_sym }
          end

          return @header
        end

        if i == 10
          break
        end
      end

      @io.rewind

      nil
    end

    # Method to skip a given number or lines.
    def skip(num)
      num.times { @io.get_entry }
    end

    # Method to iterate over a CSV IO object yielding lines or an enumerator
    #   CSV.each { |item| block }  -> ary
    #   CSV.each                   -> Enumerator
    def each(options = {})
      return to_enum :each unless block_given?

      got_header = false

      @io.each do |line|
        next if line.chomp.empty?
        
        if line[0] == '#'
          if options[:include_header] and not got_header
            got_header = true
            yield line[1 .. -1] 
          end
        else
          yield line
        end
      end

      self
    end

    # Method to iterate over a CSV IO object yielding arrays or an enumerator
    #   CSV.each_array(options={}) { |item| block } -> ary
    #   CSV.each_array(options={})                  -> Enumerator
    #
    # Options:
    #   * :delimiter - specify an alternative field delimiter (default="\s").
    #   * :columns   - specify a list or range of columns to output in that order.
    #   * :select    - select columns by header to output in that order (requires header).
    #   * :reject    - reject columns by header (requires header).
    def each_array(options = {})
      return to_enum :each_array unless block_given?

      delimiter = options[:delimiter] || @delimiter
      columns   = options[:columns]

      if options[:select]
        header = self.header(delimiter: delimiter, columns: columns)

        raise BioPieces::CSVError, "No header found" unless header

        unless ([*options[:select]] - header).empty?
          raise BioPieces::CSVError, "No such columns: #{[*options[:select]] - header}"
        end

        columns = header.map.with_index.to_h.values_at(*options[:select])
      end

      if options[:reject]
        header = self.header(delimiter: delimiter, columns: columns)

        raise BioPieces::CSVError, "No header found" unless header

        unless ([*options[:reject]] - header).empty?
          raise BioPieces::CSVError, "No such columns: #{[*options[:reject]] - header}"
        end

        columns = header.map.with_index.to_h.delete_if { |k, v| options[:reject].include? k }.values
      end

      types = nil
      check = true

      @io.each do |line|
        line.chomp!
        next if line.empty? or line[0] == '#'

        fields = line.split(delimiter)

        if columns
          types  = determine_types(line, delimiter).values_at(*columns) unless types

          if check
            if columns.max >= fields.size
              raise CSVError, "Requested columns out of bounds: #{columns.select { |c| c >= fields.size }}"
            end
            check = false
          end

          yield fields.values_at(*columns).convert_types(types)
        else
          types = determine_types(line, delimiter) unless types

          yield fields.convert_types(types)
        end
      end

      self
    end

    # Method to iterate over a CSV IO object yielding hashes or an enumerator
    #   CSV.each_hash(options={}) { |item| block } -> ary
    #   CSV.each_hash(options={})                  -> Enumerator
    #
    # Options:
    #   * :delimiter - specify an alternative field delimiter (default="\s").
    #   * :columns   - specify a list or range of columns to output.
    #   * :headers   - list of headers to use as keys.
    #   * :select    - select columns by header to output (requires header).
    #   * :reject    - reject columns by header (requires header).
    def each_hash(options = {})
      return to_enum :each_hash unless block_given?

      delimiter = options[:delimiter] || @delimiter
      columns   = options[:columns]
      header    = options[:header]

      if columns and options[:header]
        if columns.size != options[:header].size
          raise CSVError, "Requested columns and header sizes mismatch: #{columns} != #{options[:header]}"
        end
      end

      if options[:select]
        header = self.header(delimiter: delimiter, columns: columns)

        raise BioPieces::CSVError, "No header found" unless header

        unless ([*options[:select]] - header).empty?
          raise BioPieces::CSVError, "No such columns: #{[*options[:select]] - header}"
        end

        columns = header.map.with_index.to_h.values_at(*options[:select])
        header  = options[:select]
      end

      if options[:reject]
        header = self.header(delimiter: delimiter, columns: columns)

        raise BioPieces::CSVError, "No header found" unless header

        unless ([*options[:reject]] - header).empty?
          raise BioPieces::CSVError, "No such columns: #{[*options[:reject]] - header}"
        end

        columns = header.map.with_index.to_h.delete_if { |k, v| options[:reject].include? k }.values
        header.reject! { |k| options[:reject].include? k }
      end

      types = nil
      check = true

      @io.each do |line|
        line.chomp!
        next if line.empty? or line[0] == '#'
        hash = {}

        fields = line.split(delimiter)

        if columns
          types = determine_types(line, delimiter).values_at(*columns) unless types

          if check
            if columns.max > fields.size
              raise CSVError, "Requested columns out of bounds: #{columns.select { |c| c > fields.size }}"
            end

            check = false
          end

          if header
            fields.values_at(*columns).convert_types(types).each_with_index { |e, i| hash[header[i].to_sym] = e }
          else
            fields.values_at(*columns).convert_types(types).each_with_index { |e, i| hash["V#{i}".to_sym] = e }
          end
        else
          types = determine_types(line, delimiter) unless types

          if header
            if check
              if header.size > fields.size
                raise BioPieces::CSVError, "Header contains more fields than columns: #{header.size} > #{fields.size}"
              end

              check = false
            end

            fields.convert_types(types).each_with_index { |e, i| hash[header[i].to_sym] = e }
          else
            fields.convert_types(types).each_with_index { |e, i| hash["V#{i}".to_sym] = e }
          end
        end

        yield hash
      end

      self
    end

    private

    # Method that determines the data types used in a row.
    def determine_types(line, delimiter)
      types = []

      line.split(delimiter).each do |field|
        field = field.to_num

        if field.is_a? Fixnum
          types << :to_i
        elsif field.is_a? Float
          types << :to_f
        elsif field.is_a? String
          types << :to_s
        else
          types << nil
        end
      end

      types
    end

    class IO < Filesys
      def rewind
        @io.rewind
      end
    end
  end
end
