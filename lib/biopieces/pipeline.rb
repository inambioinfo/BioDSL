# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< #
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

module BioPieces
  trap("INT") { exit! } unless BioPieces::Config::DEBUG

  class PipelineError < StandardError; end

  class Pipeline
    attr_accessor :commands, :status

    include BioPieces::Commands
    include BioPieces::HistoryHelper
    include BioPieces::LogHelper
    include BioPieces::OptionsHelper
    include BioPieces::StatusHelper

    def initialize
      @options  = {}
      @commands = []
      @status   = {}
    end

    # Returns the size or number of commands in a pipeline.
    def size
      @commands.size
    end

    # Method for merging one pipeline onto another.
    def <<(pipeline)
      pipeline.commands.map { |command| self.commands << command }
      pipeline.status.map   { |status|  self.status   << status }

      self
    end

    # Method that adds two Pipelines and return a new Pipeline.
    def +(pipeline)
      raise ArgumentError, "Not a pipeline: #{pipeline.inspect}" unless self.class === pipeline

      p = self.class.new
      p << self
      p << pipeline
    end

    # Removes last command from a Pipeline and returns a new Pipeline with this command.
    def pop
      p = BioPieces::Pipeline.new
      p.commands = [@commands.pop]
      p
    end

    # Run a Pipeline.
    def run(options = {})
      raise BioPieces::PipelineError, "No commands added to pipeline" if @commands.empty?

      options_allowed(options, :verbose, :email, :progress, :subject, :input, :output, :fork, :thread)
      options_allowed_values(options, fork: [true, false, nil], thread: [true, false, nil])
      options_conflict(options, fork: :thread)
      options_tie(options, subject: :email)

      @options = options

      status_init

      if @options[:fork]
        @options[:progress] ? status_progress { run_fork }      : run_fork
      elsif @options[:thread]
        @options[:progress] ? status_progress { run_thread }    : run_thread
      else
        @options[:progress] ? status_progress { run_enumerate } : run_enumerate
      end

      @status[:status] = status_load

      pp @status if @options[:verbose]
      email_send if @options[:email]

      log_ok

      self
    rescue Exception => exception
      unless ENV['BIOPIECES_ENV'] and ENV['BIOPIECES_ENV'] == 'test'
        STDERR.puts "Error in run: " + exception.to_s
        STDERR.puts exception.backtrace if @options[:verbose]
        log_error(exception)
        exit 2
      else
        raise exception
      end
    ensure
      history_save
    end

    def run_fork
      input  = @options[:input]  || []
      output = @options[:output]
      forks  = []

      @commands[1 .. -1].reverse.each do |cmd|
        parent = BioPieces::Fork.execute do |child|
          cmd.run(child.input, output)
        end
        
        output = parent.output

        forks << parent
      end

      @commands.first.run(input, output)

      forks.reverse.each { |f| f.wait }
    end

    def run_thread
      input   = @options[:input]  || []
      output  = @options[:output]
      threads = []

      @commands[1 .. -1].reverse.each do |command|
        io_read, io_write = BioPieces::Stream.pipe

        threads << Thread.new(command, io_read, output) do |cmd, iin, iout|
          cmd.run(iin, iout)
        end

        output = io_write
      end

      @commands.first.run(input, output)

      threads.reverse.each { |t| t.join }
    end

    def run_enumerate
      enums = [@options[:input]]

      @commands.each_with_index do |command, i|
        enums << Enumerator.new do |output|
          command.run(enums[i], output)
        end
      end

      if @options[:output]
        enums.last.each { |record| @options[:output].write record }
        @options[:output].close
      else
        enums.last.each {}
      end
    end

    # format a Pipeline to a pretty string which is returned.
    def to_s
      command_string = "BP.new"

      @commands.each { |command| command_string << command.to_s }

      unless @status.empty?
        if @options.empty?
          command_string << ".run"
        else
          options = []

          @options.each_pair do |key, value|
            options << "#{key}: #{value}"
          end

          command_string << ".run(#{options.join(", ")})"
        end
      end

      command_string
    end

    # Send email notification to email address specfied in @options[:email],
    # including a optional subject specified in @options[:subject], that will
    # otherwise default to self.to_s. The body of the email will be the
    # Pipeline status.
    def email_send
      mail = Mail.new
      mail[:from]    = "#{ENV['USER']}@#{`hostname`.strip}"
      mail[:to]      = @options[:email]
      mail[:subject] = @options[:subject] || self.to_s
      mail[:body]    = "#{self.to_s}\n\n\n#{PP.pp(@status, '')}"

      mail.deliver!
    end

    private

    class Command
      attr_accessor :status
      attr_reader :name, :options, :options_orig, :lmb

      include BioPieces::StatusHelper
      include BioPieces::LogHelper
      include BioPieces::OptionsHelper

      def initialize(name, options, options_orig, lmb)
        @name         = name
        @options      = options
        @options_orig = options_orig
        @lmb          = lmb
      end

      def run(input, output)
        self.status[:time_start] = Time.now
        self.status[:status]     = "running"
        self.lmb.call(input, output, self.status)
        self.status[:time_stop]  = Time.now
        self.status[:status]     = "done"

        status_save(self.status)

        self.status
      ensure
        input.close if input.respond_to? :close
        output.close if output.respond_to? :close
      end

      def to_s
        options_list = []

        @options_orig.each do |key, value|
          if value.is_a? String
            value = Regexp::quote(value) if key == :delimiter
            options_list << %{#{key}: "#{value}"}
          elsif value.is_a? Symbol
            options_list << "#{key}: :#{value}"
          else
            options_list << "#{key}: #{value}"
          end
        end

        if @options.empty?
          ".#{@name}"
        else
          ".#{@name}(#{options_list.join(", ")})"
        end
      end
    end
  end
end
