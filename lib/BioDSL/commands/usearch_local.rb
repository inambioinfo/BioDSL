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
# This software is part of the BioDSL (www.BioDSL.org).                        #
#                                                                              #
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< #

module BioDSL
  # == Run usearch_local on sequences in the stream.
  #
  # This is a wrapper for the +usearch+ tool to run the program usearch_local.
  # Basically sequence type records are searched against a reference database
  # and records with hit information are output.
  #
  # Please refer to the manual:
  #
  # http://drive5.com/usearch/manual/cmd_usearch_local.html
  #
  # Usearch 7.0 must be installed for +usearch+ to work. Read more here:
  #
  # http://www.drive5.com/usearch/
  #
  # == Usage
  #
  #    usearch_local(<database: <file>, <identity: float>,
  #                  <strand: "plus|both">[, cpus: <uint>])
  #
  # === Options
  #
  # * database: <file>   - Database to search (in FASTA format).
  # * identity: <float>  - Similarity for matching in percent between 0.0 and
  #                        1.0.
  # * strand:   <string> - For nucleotide search report hits from plus or both
  #                        strands.
  # * cpus:     <uint>   - Number of CPU cores to use (default=1).
  #
  # == Examples
  #
  class UsearchLocal
    require 'BioDSL/helpers/aux_helper'

    include AuxHelper

    STATS = %i(records_in records_out sequences_in hits_out)

    # Constructor for UsearchLocal.
    #
    # @param  options [Hash] Options hash.
    # @option options [String]        :database
    # @option options [Float]         :identity
    # @option options [String,Symbol] :strand
    # @option options [Integer]       :cpus
    #
    # @return [UsearchLocal] Class instance.
    def initialize(options)
      @options          = options
      @options[:cpus] ||= 1

      aux_exist('usearch')
      check_options
    end

    # Return command lambda for usearch_local.
    #
    # @return [Proc] Command lambda.
    def lmb
      lambda do |input, output, status|
        status_init(status, STATS)

        TmpDir.create('in', 'out') do |tmp_in, tmp_out|
          process_input(input, output, tmp_in)
          run_usearch_local(tmp_in, tmp_out)
          process_output(output, tmp_out)
        end
      end
    end

    private

    # Check options.
    def check_options
      options_allowed(@options, :database, :identity, :strand, :cpus)
      options_required(@options, :database, :identity)
      options_allowed_values(@options, strand: ['plus', 'both', :plus, :both])
      options_files_exist(@options, :database)
      options_assert(@options, ':identity >  0.0')
      options_assert(@options, ':identity <= 1.0')
      options_assert(@options, ':cpus >= 1')
      options_assert(@options, ":cpus <= #{BioDSL::Config::CORES_MAX}")
    end

    # Process input and emit to the output stream while saving all records
    # containing sequences to a temporary FASTA file.
    #
    # @param input [Enumerator] Input stream.
    # @param output [Enumerator::Yielder] Output stream.
    # @param tmp_in [String] Path to temporary file.
    def process_input(input, output, tmp_in)
      BioDSL::Fasta.open(tmp_in, 'w') do |ios|
        input.each_with_index do |record, i|
          @status[:records_in] += 1

          output << record

          @status[:records_out] += 1

          next unless record[:SEQ]

          @status[:sequences_in] += 1
          seq_name = record[:SEQ_NAME] || i.to_s

          entry = BioDSL::Seq.new(seq_name: seq_name, seq: record[:SEQ])

          ios.puts entry.to_fasta
        end
      end
    end

    # Run usearch local on the input file and save results in the output file.
    def run_usearch_local(tmp_in, tmp_out)
      run_opts = {
        input: tmp_in,
        output: tmp_out,
        database: @options[:database],
        strand: @options[:strand],
        identity: @options[:identity],
        cpus: @options[:cpus],
        verbose: @options[:verbose]
      }

      BioDSL::Usearch.usearch_local(run_opts)
    rescue BioDSL::UsearchError => e
      raise unless e.message =~ /Empty input file/
    end

    # Parse usearch output file and emit records to the output stream.
    #
    # @param output [Enumerator::Yielder] Output stream.
    # @param tmp_out [String] Path to output file.
    def process_output(output, tmp_out)
      BioDSL::Usearch.open(tmp_out) do |ios|
        ios.each(:uc) do |record|
          record[:RECORD_TYPE] = 'usearch'
          output << record
          @status[:hits_out] += 1
          @status[:records_out] += 1
        end
      end
    end
  end
end
