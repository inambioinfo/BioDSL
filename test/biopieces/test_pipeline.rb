#!/usr/bin/env ruby
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', '..')

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< #
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
# This software is part of Biopieces (www.biopieces.org).                      #
#                                                                              #
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< #

require 'test/helper'

# rubocop: disable ClassLength

# Test class for Pipeline.
class PipelineTest < Test::Unit::TestCase
  require 'yaml'

  def setup
    @tmpdir = Dir.mktmpdir('BioPieces')

    setup_fasta_files

    Mail.defaults do
      delivery_method :test
    end

    @p = BP.new
  end

  def setup_fasta_files
    @fasta_file  = File.join(@tmpdir, 'test.fna')
    @fasta_file2 = File.join(@tmpdir, 'test2.fna')

    File.open(@fasta_file, 'w') do |ios|
      ios.puts <<-DATA.gsub(/^\s+\|/, '')
        |>test1
        |atcg
        |>test2
        |tgac
      DATA
    end
  end

  def teardown
    FileUtils.rm_r @tmpdir

    Mail::TestMailer.deliveries.clear
  end

  test 'BioPieces::Pipeline#to_s w/o options and w/o .run() returns OK' do
    @p.commands << BioPieces::Command.new('dump', nil, {})
    expected = %(BP.new.dump)
    assert_equal(expected, @p.to_s)
  end

  test 'BioPieces::Pipeline#to_s with options and w/o .run() returns OK' do
    @p.commands << BioPieces::Command.new('read_fasta', nil, input: 'test.fna')
    expected = %(BP.new.read_fasta(input: "test.fna"))
    assert_equal(expected, @p.to_s)
  end

  test 'BioPieces::Pipeline#to_s w/o options and .run() returns OK' do
    @p.commands << BioPieces::Command.new('dump', nil, {})
    @p.complete = true
    expected = %(BP.new.dump.run)
    assert_equal(expected, @p.run.to_s)
  end

  test 'BioPieces::Pipeline#to_s with options and .run() returns OK' do
    @p.commands << BioPieces::Command.new('read_fasta', nil, input: 'test.fna')
    @p.complete = true
    expected = %{BP.new.read_fasta(input: "test.fna").run}
    assert_equal(expected, @p.run.to_s)
  end

  test 'BioPieces::Pipeline#run with no commands raises' do
    assert_raise(BioPieces::PipelineError) { @p.run }
  end

  test 'BioPieces::Pipeline#size returns correctly' do
    assert_equal(0, @p.size)
    @p.dump
    assert_equal(1, @p.size)
  end

  test 'BioPieces::Pipeline#+ with non-Pipeline object raises' do
    assert_raise(BioPieces::PipelineError) { @p + 'foo' }
  end

  test 'BioPieces::Pipeline#+ with Pipeline object dont raise' do
    assert_nothing_raised { @p + @p }
  end

  test 'BioPieces::Pipeline#+ of two Pipelines return correctly' do
    p = BioPieces::Pipeline.new.dump(first: 2)
    assert_equal('BP.new.dump(first: 2)', (@p + p).to_s)
  end

  test 'BioPieces::Pipeline#+ of three Pipelines return correctly' do
    p1 = BioPieces::Pipeline.new.dump(first: 2)
    p2 = BioPieces::Pipeline.new.dump(last: 3)
    assert_equal('BP.new.dump(first: 2).dump(last: 3)', (@p + p1 + p2).to_s)
  end

  test 'BioPieces::Pipeline#pop decreases size' do
    @p.dump
    assert_equal(1, @p.size)
    @p.pop
    assert_equal(0, @p.size)
    @p.pop
    assert_equal(0, @p.size)
  end

  test 'BioPieces::Pipeline#pop returns correctly' do
    @p.dump
    assert_equal(BioPieces::Pipeline.new.dump.to_s, @p.pop.to_s)
    assert_equal(BioPieces::Pipeline.new.to_s, @p.to_s)
  end

  test 'BioPieces::Pipeline#status without .run() returns correctly' do
    status = @p.read_fasta(input: __FILE__).status
    assert_equal({}, status.first.status)
  end

  test 'BioPieces::Pipeline#status with .run() returns correctly' do
    expected = %{BioPieces::Pipeline.new.read_fasta(input: "#{@fasta_file}")}
    @p.expects(:status).returns(expected)
    assert_equal(expected, @p.read_fasta(input: @fasta_file).run.status)
  end

  test 'BioPieces::Pipeline#run with disallowed option raises' do
    assert_raise(BioPieces::OptionError) do
      @p.read_fasta(input: @fasta_file).run(foo: 'bar')
    end
  end

  test 'BioPieces::Pipeline#run with verbose returns correctly' do
    stdout = capture_stdout do
      @p.read_fasta(input: @fasta_file).run(verbose: true)
    end

    expected = capture_stdout { puts @p.status }
    assert_equal(expected, stdout)
  end

  test 'BioPieces::Pipeline#run returns correctly' do
    @p.read_fasta(input: @fasta_file).write_fasta(output: @fasta_file2).run

    expected = File.read(@fasta_file)
    result   = File.read(@fasta_file2)

    assert_equal(expected, result)
  end

  test 'BioPieces::Pipeline#run with subject but no email raises' do
    assert_raise(BioPieces::OptionError) do
      @p.read_fasta(input: @fasta_file).run(subject: 'foobar')
    end
  end

  test 'BioPieces::Pipeline#run with email sends mail correctly' do
    @p.read_fasta(input: @fasta_file).run(email: 'test@foobar.com')
    assert_equal(1, Mail::TestMailer.deliveries.length)
    assert_equal(@p.to_s, Mail::TestMailer.deliveries.first.subject)
  end

  test 'BioPieces::Pipeline#run with email and subject sends correctly' do
    @p.read_fasta(input: @fasta_file).
      run(email: 'test@foobar.com', subject: 'foobar')

    assert_equal(1, Mail::TestMailer.deliveries.length)
    assert_equal('foobar', Mail::TestMailer.deliveries.first.subject)
  end
end
