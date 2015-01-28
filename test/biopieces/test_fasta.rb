#!/usr/bin/env ruby
$:.unshift File.join(File.dirname(__FILE__), '..', '..')

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< #
#                                                                                #
# Copyright (C) 2007-2015 Martin Asser Hansen (mail@maasha.dk).                  #
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

require 'test/helper'

class FastaTest < Test::Unit::TestCase
  test "#get_entry obtains the correct seq_name" do
    fasta = BioPieces::Fasta.new(StringIO.new(">test\nATCG\n"))
    assert_equal("test", fasta.get_entry.seq_name)
  end

  test "#get_entry obtains the correct seq without trailing newlines" do
    fasta = BioPieces::Fasta.new(StringIO.new(">test\nATCG"))
    assert_equal("ATCG", fasta.get_entry.seq)
  end

  test "#get_entry obtains the correct seq with trailing newlines" do
    fasta = BioPieces::Fasta.new(StringIO.new(">test\nATCG\n\n\n"))
    assert_equal("ATCG", fasta.get_entry.seq)
  end

  test "#get_entry rstrips whitespace from seq_name" do
    fasta = BioPieces::Fasta.new(StringIO.new(">test\n\r\t ATCG\n"))
    assert_equal("test", fasta.get_entry.seq_name)
  end

  test "#get_entry strips whitespace from seq" do
    fasta = BioPieces::Fasta.new(StringIO.new(">test\n\r\t AT\n\r\t CG\n\r\t "))
    assert_equal("ATCG", fasta.get_entry.seq)
  end

  test "#get_entry with two entries returns correctly" do
    fasta = BioPieces::Fasta.new(StringIO.new(">test1\n\r\t AT\n\r\t CG\n\r\t \n>test2\n\r\t atcg\n"))
    assert_equal("ATCG", fasta.get_entry.seq)
    assert_equal("atcg", fasta.get_entry.seq)
  end

  test "#get_entry without seq_name raises" do
    fasta = BioPieces::Fasta.new(StringIO.new("ATCG\n"))
    assert_raise(BioPieces::FastaError) { fasta.get_entry }
  end

  test "#get_entry without seq raises" do
    fasta = BioPieces::Fasta.new(StringIO.new(">test\n\n"))
    assert_raise(BioPieces::FastaError) { fasta.get_entry }
  end

# FIXME
#  test "#get_entry raises on missing > in seq_name" do
#    fasta = BioPieces::Fasta.new(StringIO.new("test\nATCG\n"))
#    assert_raise( BioPieces::FastaError ) { fasta.get_entry }
#  end

  test "#get_decimal_qual without seq_name raises" do
    fasta = BioPieces::Fasta.new(StringIO.new("10 20 30 40\n"))
    assert_raise(BioPieces::FastaError) { fasta.get_decimal_qual }
  end

  test "#get_decimal_qual without qual raises" do
    fasta = BioPieces::Fasta.new(StringIO.new(">test\n"))
    assert_raise(BioPieces::FastaError) { fasta.get_decimal_qual }
  end

  test "#get_decimal_qual returns correctly" do
    fasta = BioPieces::Fasta.new(StringIO.new(">test\n0 10 20 30 40\n"))
    assert_equal("!+5?I", fasta.get_decimal_qual.qual)
  end
end
