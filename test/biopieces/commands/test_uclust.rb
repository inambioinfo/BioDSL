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

class TestUclust < Test::Unit::TestCase 
  test "BioPieces::Pipeline#uclust with disallowed option raises" do
    p = BioPieces::Pipeline.new
    assert_raise(BioPieces::OptionError) { p.uclust(foo: "bar") }
  end

  test "BioPieces::Pipeline#uclust with allowed option don't raise" do
    p = BioPieces::Pipeline.new
    assert_nothing_raised { p.uclust(identity: 1, strand: :both) }
  end

  test "BioPieces::Pipeline#uclust outputs msa correctly" do
    input, output   = BioPieces::Stream.pipe
    input2, output2 = BioPieces::Stream.pipe

    output.write({one: 1, two: 2, three: 3})
    output.write({SEQ: "gtgtgtagctacgatcagctagcgatcgagctatatgttt"})
    output.write({SEQ: "atcgatcgatcgatcgatcgatcgatcgtacgacgtagct"})
    output.close

    p = BioPieces::Pipeline.new
    p.uclust(identity: 0.97, strand: "plus", align: true).run(input: input, output: output2)
    result   = input2.map { |h| h.to_s }.sort_by { |a| a.to_s }.reduce(:<<)
    expected = ""
    expected << %Q{{:RECORD_TYPE=>"uclust", :CLUSTER=>0, :SEQ_NAME=>"*1", :SEQ=>"GTgtgtAGCTACGATCAGCTAGCGATCGAGCTATATGTTT", :SEQ_LEN=>40}}
    expected << %Q{{:RECORD_TYPE=>"uclust", :CLUSTER=>1, :SEQ_NAME=>"*2", :SEQ=>"ATCGATCGATCGATCGATCGATCGATCGTACGACGTAGCT", :SEQ_LEN=>40}}
    expected << %Q{{:one=>1, :two=>2, :three=>3}}

    assert_equal(expected, result)
  end
end
