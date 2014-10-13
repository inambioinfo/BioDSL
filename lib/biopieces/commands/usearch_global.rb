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
# This software is part of the Biopieces framework (www.biopieces.org).          #
#                                                                                #
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< #

module BioPieces
  module Commands
    # == Run usearch_global on sequences in the stream.
    # 
    # This is a wrapper for the +usearch+ tool to run the program usearch_global.
    # Basically sequence type records are searched against a reference database
    # and records with hit information are output.
    #
    # Please refer to the manual:
    #
    # http://drive5.com/usearch/manual/usearch_global.html
    #
    # Usearch 7.0 must be installed for +usearch+ to work. Read more here:
    #
    # http://www.drive5.com/usearch/
    # 
    # == Usage
    # 
    #    usearch_global(<database: <file>, <identity: float>, <strand: "plus|both">)
    # 
    # === Options
    #
    # * database: <file>   - Database to search (in FASTA format).
    # * identity: <float>  - Similarity for matching in percent between 0.0 and 1.0.
    # * strand:   <string> - For nucleotide search report hits from plus or both strands.
    #
    # == Examples
    # 
    def usearch_global(options = {})
      options_orig = options.dup
      options_allowed(options, :database, :identity, :strand)
      options_required(options, :database, :identity)
      options_allowed_values(options, strand: ["plus", "both"])
      options_files_exist(options, :database)
      options_assert(options, ":identity >  0.0")
      options_assert(options, ":identity <= 1.0")

      lmb = lambda do |input, output, status|
        status[:sequences_in] = 0
        status[:hits_out]     = 0

        status_track(status) do
          begin
            tmp_in  = Tempfile.new("uclust")
            tmp_out = Tempfile.new("uclust")

            BioPieces::Fasta.open(tmp_in, 'w') do |ios|
              input.each_with_index do |record, i|
                status[:records_in] += 1

                output << record

                status[:records_out] += 1

                if record[:SEQ]
                  status[:sequences_in] += 1
                  seq_name = record[:SEQ_NAME] || i.to_s

                  entry = BioPieces::Seq.new(seq_name: seq_name, seq: record[:SEQ])

                  ios.puts entry.to_fasta
                end
              end
            end

            BioPieces::Usearch.usearch_global(input: tmp_in, 
                                              output: tmp_out,
                                              database: options[:database],
                                              strand: options[:strand],
                                              identity: options[:identity],
                                              verbose: options[:verbose])

            BioPieces::Usearch.open(tmp_out) do |ios|
              ios.each(:uc) do |record|
                record[:record_type] = "usearch"
                output << record
                status[:hits_out]    += 1
                status[:records_out] += 1
              end
            end
          ensure
            tmp_in.unlink
            tmp_out.unlink
          end
        end
      end

      @commands << BioPieces::Pipeline::Command.new(__method__, options, options_orig, lmb)

      self
    end
  end
end

