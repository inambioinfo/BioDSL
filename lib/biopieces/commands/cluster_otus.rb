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
    # == Create OTUs from sequences in the stream.
    # 
    # Use the +usearch+ program cluster_otus to cluster sequences in the stream
    # and output a representative sequence from each cluster. Sequences must
    # be dereplicated and sorted according to +SEQ_COUNT+ in decreasing order.
    #
    # Please refer to the manual:
    #
    # http://drive5.com/usearch/manual/cluster_otus.html
    #
    # Usearch 7.0 must be installed for +usearch+ to work. Read more here:
    #
    # http://www.drive5.com/usearch/
    # 
    # == Usage
    # 
    #    cluster_otus()
    # 
    # === Options
    #
    # == Examples
    #
    # To create OTU clusters do:
    #
    #     BP.new.
    #     read_fasta(input: "in.fna").
    #     dereplicate_seq.
    #     sort(key: :SEQ_COUNT, reverse: true).
    #     cluster_otus.
    #     run
    def cluster_otus(options = {})
      options_orig = options.dup
      options_allowed(options, nil)

      lmb = lambda do |input, output, status|
        status[:sequences_in]  = 0
        status[:sequences_out] = 0

        status_track(status) do
          begin
            tmp_in  = Tempfile.new("uclust")
            tmp_out = Tempfile.new("uclust")

            BioPieces::Fasta.open(tmp_in, 'w') do |ios|
              input.each_with_index do |record, i|
                status[:records_in] += 1

                if record[:SEQ]
                  status[:sequences_in] += 1
                  seq_name = record[:SEQ_NAME] || i.to_s

                  if record[:SEQ_COUNT]
                    seq_name << ";size=#{record[:SEQ_COUNT]}"
                  else
                    raise BioPieces::SeqError, "Missing SEQ_COUNT"
                  end

                  entry = BioPieces::Seq.new(seq_name: seq_name, seq: record[:SEQ])

                  ios.puts entry.to_fasta
                else
                  output << record
                  status[:records_out] += 1
                end
              end
            end

            BioPieces::Usearch.cluster_otus(input: tmp_in, output: tmp_out, verbose: options[:verbose])

            Fasta.open(tmp_out) do |ios|
              ios.each do |entry|
                record = entry.to_bp

                if record[:SEQ_NAME] =~ /;size=(\d+)$/
                  record[:SEQ_COUNT] = $1.to_i
                  record[:SEQ_NAME].sub!(/;size=\d+$/, '')
                else
                  raise BioPieces::UsearchError, "Missing size in SEQ_NAME: #{record[:SEQ_NAME]}"
                end

                output << record
                status[:sequences_out] += 1
                status[:records_out]   += 1
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
