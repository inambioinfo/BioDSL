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
  # rubocop:disable ClassLength

  # == Genecall sequences in the stream.
  #
  # +Genecall+ predict genes in prokaryotic single genomes or metagenoemes using
  # Prodigal 2.6 which must be installed:
  #
  # http://denovoassembler.sourceforge.net/
  #
  # == Usage
  #
  #    assemble_seq_ray([procedure: <string>[, closed_ends: <bool>
  #                     [, masked: <bool>]]])
  #
  # === Options
  #
  # * procedure:   <string> - Single or meta (default: single).
  # * closed_ends: <bool>   - Don't allow truncated gene at ends.
  # * masked:      <bool>   - Ignore stretch of Ns.
  #
  # == Examples
  #
  # To genecall a genome do:
  #
  #    BP.new.
  #    read_fasta(input: "contigs.fna").
  #    genecall.
  #    grab(select: "genecall", key: :type, exact: true).
  #    write_fasta(output: "genes.faa").
  #    run
  class Genecall
    require 'English'
    require 'biopieces/helpers/aux_helper'

    include AuxHelper

    STATS = %i(records_in records_out sequences_in sequences_out residues_in
               residues_out)

    # Constructor for the Genecall class.
    #
    # @param [Hash] options Options hash.
    # @option options [Symbol]  :procedure used for genecalling.
    # @option options [Boolean] :closed_ends disallow truncated genes at ends.
    # @option options [Boolean] :masked ignore stretch of Ns.
    #
    # @return [Genecall] Returns an instance of the class.
    def initialize(options)
      @options = options

      aux_exist('prodigal')
      defaults
      check_options
    end

    # Return a lambda for the genecall command.
    #
    # @return [Proc] Returns the command lambda.
    def lmb
      lambda do |input, output, status|
        status_init(status, STATS)

        TmpDir.create('in.fa', 'out.fa') do |tmp_fa, tmp_aa|
          process_input(input, output, tmp_fa)
          run_prodigal(tmp_fa, tmp_aa)
          process_output(output, tmp_aa)
        end
      end
    end

    private

    # Run Prodigal on the input file.
    #
    # @param tmp_fa  [String] Path to input FASTA file.
    # @param tmp_aa  [String] Path to output FASTA file.
    def run_prodigal(tmp_fa, tmp_aa)
      cmd = []
      cmd << 'prodigal'
      cmd << '-f gff'
      cmd << '-c' if @options[:closed_ends]
      cmd << '-m' if @options[:masked]
      cmd << "-p #{@options[:procedure]}"
      cmd << "-i #{tmp_fa}"
      cmd << "-a #{tmp_aa}"
      cmd << '-q'               unless BioPieces.verbose
      cmd << '> /dev/null 2>&1' unless BioPieces.verbose

      cmd_line = cmd.join(' ')

      $stderr.puts "Running: #{cmd_line}" if BioPieces.verbose
      system(cmd_line)

      fail cmd_line unless $CHILD_STATUS.success?
    end

    # Check the options.
    def check_options
      options_allowed(@options, :procedure, :closed_ends, :masked)
      options_allowed_values(@options, procedure: ['single', 'meta', :single,
                                                   :meta])
      options_allowed_values(@options, closed_ends: [nil, true, false])
      options_allowed_values(@options, masked: [nil, true, false])
    end

    # Set the default option values.
    def defaults
      @options[:procedure] ||= :single
    end

    # Read all records from input and emit non-sequence records to the output
    # stream. Sequence records are saved to a temporary file.
    #
    # @param input [Enumerator] input stream.
    # @param output [Enumerator::Yielder] Output stream.
    # @param fa_in [String] Path to temporary FASTA file.
    def process_input(input, output, fa_in)
      BioPieces::Fasta.open(fa_in, 'w') do |fasta_io|
        input.each do |record|
          @status[:records_in] += 1

          if record.key? :SEQ
            entry = BioPieces::Seq.new_bp(record)

            @status[:sequences_in] += 1
            @status[:residues_in]  += entry.length

            fasta_io.puts entry.to_fasta
          else
            @status[:records_out] += 1
            output.puts record
          end
        end
      end
    end

    # Read the output from file and emit to the output stream.
    #
    # @param output  [Enumerator::Yielder] Output stream.
    # @param tmp_aa  [String]              Path to output FASTA file.
    def process_output(output, tmp_aa)
      BioPieces::Fasta.open(tmp_aa, 'r') do |ios|
        ios.each do |entry|
          record = {}
          fields = entry.seq_name.split(' # ')

          record[:RECORD_TYPE] = 'gene'
          record[:S_ID]        = fields[0]
          record[:S_BEG]       = fields[1].to_i - 1
          record[:S_END]       = fields[2].to_i - 1
          record[:S_LEN]       = record[:S_END] - record[:S_BEG] + 1
          record[:STRAND]      = fields[3] == '1' ? '+' : '-'
          record[:SEQ]         = entry.seq
          record[:SEQ_LEN]     = entry.length

          output << record

          @status[:records_out]   += 1
          @status[:sequences_out] += 1
          @status[:residues_out]  += entry.length
        end
      end
    end
  end
end
