#!/usr/bin/env ruby
$:.unshift File.join(File.dirname(__FILE__), '..', '..', '..')

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

class TestIndexTaxonomy < Test::Unit::TestCase 
  def setup
    @tmpdir = Dir.mktmpdir("BioPieces")

    @input, @output   = BioPieces::Stream.pipe
    @input2, @output2 = BioPieces::Stream.pipe

    @p = BioPieces::Pipeline.new
  end

  def teardown
    FileUtils.rm_r @tmpdir
  end

  test "BioPieces::Pipeline::IndexTaxonomy with invalid options raises" do
    assert_raise(BioPieces::OptionError) { @p.index_taxonomy(output_dir: @tmpdir, foo: "bar") }
  end

  test "BioPieces::Pipeline::IndexTaxonomy with valid options don't raise" do
    assert_nothing_raised { @p.index_taxonomy(prefix: "foo", output_dir: @tmpdir) }
  end

#  test "BioPieces::Pipeline::IndexTaxonomy returns correctly" do
#    @output.write({SEQ: "AT--C.G~"})
#    @output.close
#    @p.index_taxonomy(output_dir: @tmpdir).run(input: @input, output: @output2)
#
#    result   = @input2.map { |h| h.to_s }.reduce(:<<)
#    expected = '{:SEQ=>"ATCG", :SEQ_LEN=>4}'
#
#    assert_equal(expected, result)
#  end
end
