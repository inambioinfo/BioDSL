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

class TestGrab < Test::Unit::TestCase 
  def setup
    @tmpdir        = Dir.mktmpdir("BioPieces")
    @pattern_file  = File.join(@tmpdir, 'patterns.txt')
    @pattern_file2 = File.join(@tmpdir, 'patterns2.txt')

    File.open(@pattern_file, 'w') do |ios|
      ios.puts "test"
      ios.puts "seq"
    end

    File.open(@pattern_file2, 'w') do |ios|
      ios.puts 4
      ios.puts "SEQ"
    end

    @input, @output   = BioPieces::Stream.pipe
    @input2, @output2 = BioPieces::Stream.pipe

    hash1 = {SEQ_NAME: "test1", SEQ: "atcg", SEQ_LEN: 4}
    hash2 = {SEQ_NAME: "test2", SEQ: "DSEQM", SEQ_LEN: 5}
    hash3 = {FOO: "SEQ"}

    @output.write hash1
    @output.write hash2
    @output.write hash3
    @output.close

    @p = BioPieces::Pipeline.new
  end

  def teardown
    FileUtils.rm_r @tmpdir
  end

  test "BioPieces::Pipeline::Grab with invalid options raises" do
    assert_raise(BioPieces::OptionError) { @p.grab(foo: "bar") }
  end

  test "BioPieces::Pipeline::Grab with select and reject options raises" do
    assert_raise(BioPieces::OptionError) { @p.grab(select: "foo", reject: "bar") }
  end

  test "BioPieces::Pipeline::Grab with keys_only and values_only options raises" do
    assert_raise(BioPieces::OptionError) { @p.grab(select: "foo", keys_only: true, values_only: true) }
  end

  test "BioPieces::Pipeline::Grab with evaluate and conflicting keys raises" do
    assert_raise(BioPieces::OptionError) { @p.grab(evaluate: 0, select: "foo") }
    assert_raise(BioPieces::OptionError) { @p.grab(evaluate: 0, reject: "foo") }
    assert_raise(BioPieces::OptionError) { @p.grab(evaluate: 0, keys: "foo") }
    assert_raise(BioPieces::OptionError) { @p.grab(evaluate: 0, keys_only: true) }
    assert_raise(BioPieces::OptionError) { @p.grab(evaluate: 0, values_only: true) }
    assert_raise(BioPieces::OptionError) { @p.grab(evaluate: 0, ignore_case: true) }
    assert_raise(BioPieces::OptionError) { @p.grab(evaluate: 0, exact: true) }
  end

  test "BioPieces::Pipeline::Grab with keys and keys_only or valuess_only raises" do
    assert_raise(BioPieces::OptionError) { @p.grab(keys: :FOO, keys_only: true) }
    assert_raise(BioPieces::OptionError) { @p.grab(keys: :FOO, values_only: true) }
  end

  test "BioPieces::Pipeline::Grab with missing select_file raises" do
    assert_raise(BioPieces::OptionError) { @p.grab(select_file: "___select") }
  end

  test "BioPieces::Pipeline::Grab with missing reject_file raises" do
    assert_raise(BioPieces::OptionError) { @p.grab(reject_file: "___reject") }
  end

  test "BioPieces::Pipeline::Grab#to_s with select and symbol key return correctly" do
    @p.grab(select: :SEQ_NAME)
    expected = "BP.new.grab(select: :SEQ_NAME)"
    assert_equal(expected, @p.to_s)
  end

  test "BioPieces::Pipeline::Grab with no hits return correctly" do
    @p.grab(select: "fish").run(input: @input, output: @output2)

    stream_result = @input2.map { |h| h.to_s }.reduce(:<<)
    assert_nil(stream_result)
  end

  test "BioPieces::Pipeline::Grab with select and key hit return correctly" do
    @p.grab(select: "SEQ_NAME").run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = ""
    stream_expected << '{:SEQ_NAME=>"test1", :SEQ=>"atcg", :SEQ_LEN=>4}'
    stream_expected << '{:SEQ_NAME=>"test2", :SEQ=>"DSEQM", :SEQ_LEN=>5}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with multiple select patterns return correctly" do
    @p.grab(select: ["est1", "QM"]).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = ""
    stream_expected << '{:SEQ_NAME=>"test1", :SEQ=>"atcg", :SEQ_LEN=>4}'
    stream_expected << '{:SEQ_NAME=>"test2", :SEQ=>"DSEQM", :SEQ_LEN=>5}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with multiple reject patterns return correctly" do
    @p.grab(reject: ["est1", "QM"]).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = '{:FOO=>"SEQ"}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with reject and key hit return correctly" do
    @p.grab(reject: "SEQ_NAME").run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = '{:FOO=>"SEQ"}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with reject with symbol return correctly" do
    @p.grab(reject: :SEQ_NAME).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = '{:FOO=>"SEQ"}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with select and value hit return correctly" do
    @p.grab(select: "test1").run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = '{:SEQ_NAME=>"test1", :SEQ=>"atcg", :SEQ_LEN=>4}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with reject and value hit return correctly" do
    @p.grab(reject: "test1").run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = ""
    stream_expected << '{:SEQ_NAME=>"test2", :SEQ=>"DSEQM", :SEQ_LEN=>5}'
    stream_expected << '{:FOO=>"SEQ"}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with select and keys_only return correctly" do
    @p.grab(select: "SEQ", keys_only: true).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = ""
    stream_expected << '{:SEQ_NAME=>"test1", :SEQ=>"atcg", :SEQ_LEN=>4}'
    stream_expected << '{:SEQ_NAME=>"test2", :SEQ=>"DSEQM", :SEQ_LEN=>5}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with reject and keys_only return correctly" do
    @p.grab(reject: "SEQ", keys_only: true).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = '{:FOO=>"SEQ"}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with select and values_only return correctly" do
    @p.grab(select: "SEQ", values_only: true).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = ""
    stream_expected << '{:SEQ_NAME=>"test2", :SEQ=>"DSEQM", :SEQ_LEN=>5}'
    stream_expected << '{:FOO=>"SEQ"}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with reject and values_only return correctly" do
    @p.grab(reject: "SEQ", values_only: true).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = '{:SEQ_NAME=>"test1", :SEQ=>"atcg", :SEQ_LEN=>4}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with select and values_only and anchor return correctly" do
    @p.grab(select: "^SEQ", values_only: true).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = '{:FOO=>"SEQ"}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with reject and values_only and anchor return correctly" do
    @p.grab(reject: "^SEQ", values_only: true).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = ""
    stream_expected << '{:SEQ_NAME=>"test1", :SEQ=>"atcg", :SEQ_LEN=>4}'
    stream_expected << '{:SEQ_NAME=>"test2", :SEQ=>"DSEQM", :SEQ_LEN=>5}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with select and ignore_case return correctly" do
    @p.grab(select: "ATCG", ignore_case: true).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = '{:SEQ_NAME=>"test1", :SEQ=>"atcg", :SEQ_LEN=>4}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with reject and ignore_case return correctly" do
    @p.grab(reject: "ATCG", ignore_case: true).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = ""
    stream_expected << '{:SEQ_NAME=>"test2", :SEQ=>"DSEQM", :SEQ_LEN=>5}'
    stream_expected << '{:FOO=>"SEQ"}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with select and specified keys return correctly" do
    @p.grab(select: "SEQ", keys: :FOO).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = '{:FOO=>"SEQ"}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with select and multiple keys in Array return correctly" do
    @p.grab(select: "SEQ", keys: [:FOO, :SEQ]).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = ""
    stream_expected << '{:SEQ_NAME=>"test2", :SEQ=>"DSEQM", :SEQ_LEN=>5}'
    stream_expected << '{:FOO=>"SEQ"}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with select and multiple keys in String return correctly" do
    @p.grab(select: "SEQ", keys: ":FOO, :SEQ").run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = ""
    stream_expected << '{:SEQ_NAME=>"test2", :SEQ=>"DSEQM", :SEQ_LEN=>5}'
    stream_expected << '{:FOO=>"SEQ"}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with reject and specified keys return correctly" do
    @p.grab(reject: "SEQ", keys: :FOO).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = ""
    stream_expected << '{:SEQ_NAME=>"test1", :SEQ=>"atcg", :SEQ_LEN=>4}'
    stream_expected << '{:SEQ_NAME=>"test2", :SEQ=>"DSEQM", :SEQ_LEN=>5}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with evaluate return correctly" do
    @p.grab(evaluate: ":SEQ_LEN > 4").run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = '{:SEQ_NAME=>"test2", :SEQ=>"DSEQM", :SEQ_LEN=>5}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with select_file return correctly" do
    @p.grab(select_file: @pattern_file).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = ""
    stream_expected << '{:SEQ_NAME=>"test1", :SEQ=>"atcg", :SEQ_LEN=>4}'
    stream_expected << '{:SEQ_NAME=>"test2", :SEQ=>"DSEQM", :SEQ_LEN=>5}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with select and exact without match return correctly" do
    @p.grab(select: "tcg", exact: true).run(input: @input, output: @output2)

    stream_result = @input2.map { |h| h.to_s }.reduce(:<<)
    assert_nil(stream_result)
  end

  test "BioPieces::Pipeline::Grab with select and exact with match return correctly" do
    @p.grab(select: "atcg", exact: true).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = '{:SEQ_NAME=>"test1", :SEQ=>"atcg", :SEQ_LEN=>4}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with select and exact with number match return correctly" do
    @p.grab(select: 4, exact: true).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = '{:SEQ_NAME=>"test1", :SEQ=>"atcg", :SEQ_LEN=>4}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with select and exact with number and keys_only match return correctly" do
    @p.grab(select: 4, exact: true, keys_only: true).run(input: @input, output: @output2)

    stream_result = @input2.map { |h| h.to_s }.reduce(:<<)
    assert_nil(stream_result)
  end

  test "BioPieces::Pipeline::Grab with select and exact with number and values_only match return correctly" do
    @p.grab(select: 4, exact: true, values_only: true).run(input: @input, output: @output2)

    stream_result = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = '{:SEQ_NAME=>"test1", :SEQ=>"atcg", :SEQ_LEN=>4}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with select and exact and keys and no match return correctly" do
    @p.grab(select: "atcg", exact: true, keys: :SEQ_LEN).run(input: @input, output: @output2)

    stream_result = @input2.map { |h| h.to_s }.reduce(:<<)
    assert_nil(stream_result)
  end

  test "BioPieces::Pipeline::Grab with select and exact and keys and match return correctly" do
    @p.grab(select: "atcg", exact: true, keys: :SEQ).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = '{:SEQ_NAME=>"test1", :SEQ=>"atcg", :SEQ_LEN=>4}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with select and exact and keys_only and no match return correctly" do
    @p.grab(select: "atcg", exact: true, keys_only: true).run(input: @input, output: @output2)

    stream_result = @input2.map { |h| h.to_s }.reduce(:<<)
    assert_nil(stream_result)
  end

  test "BioPieces::Pipeline::Grab with select and exact and keys_only and String match return correctly" do
    @p.grab(select: "FOO", exact: true, keys_only: true).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = '{:FOO=>"SEQ"}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with select and exact and keys_only and Symbol match return correctly" do
    @p.grab(select: :FOO, exact: true, keys_only: true).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = '{:FOO=>"SEQ"}'
    assert_equal(stream_expected, stream_result)
  end

  test "BioPieces::Pipeline::Grab with reject_file return correctly" do
    @p.grab(reject_file: @pattern_file2, keys: :SEQ).run(input: @input, output: @output2)

    stream_result   = @input2.map { |h| h.to_s }.reduce(:<<)
    stream_expected = ""
    stream_expected << '{:SEQ_NAME=>"test1", :SEQ=>"atcg", :SEQ_LEN=>4}'
    stream_expected << '{:FOO=>"SEQ"}'
    assert_equal(stream_expected, stream_result)
  end
end

