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
# This software is part of Biopieces (www.biopieces.org).                        #
#                                                                                #
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< #

module BioPieces
  module OptionsHelper
    class BioPieces::OptionError < StandardError; end;

    # Method that raises of @options include any option not in the allowed list.
    def options_allowed(*allowed)
      @options.each_key do |option|
        unless allowed.include? option
          raise BioPieces::OptionError, "Disallowed option: #{option}. Allowed options: #{allowed.join(", ")}"
        end
      end
    end

    # Method that raises if @options don't include options in the required list.
    def options_required(*required)
      required.each do |option|
        unless @options[option]
          raise BioPieces::OptionError, "Required option missing: #{option}. Required options: #{required.join(", ")}"
        end
      end
    end

    # Method that raises if @options include multiple options in the unique list.
    def options_unique(*unique)
      lookup = []

      unique.each do |option|
        lookup << option if @options[option]
      end

      if lookup.size > 1
        raise BioPieces::OptionError, "Multiple uniques options used: #{unique.join(", ")}"
      end
    end

    # Method that sets a default option value if this is not already set.
    def option_default(option, value)
      @options[option] ||= value
    end

    def assert(&b)
      unless b.call
        raise "assertion failed"
      end
    end
  end
end
