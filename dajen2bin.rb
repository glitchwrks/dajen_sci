#!/usr/bin/env ruby

############################################################
#This program is released under the GNU GPL v3. See LICENSE
#and/or GPL-3.0 in the project root for more information.
#
#(c) 2015 The Glitch Works
#(c) 2021 Glitch Works, LLC
#http://www.glitchwrks.com/
############################################################

unless ARGV[0] && File.exist?(ARGV[0]) && ARGV[1]
  puts "Convert Dajen SCI 'D'isplay output dump to binary file\n(c) 2015 The Glitch Works\nhttp://www.glitchwrks.com\n\n"
  puts "USAGE: dajen2bin.rb input.txt output.bin"
  puts "       input.txt  - Dajen SCI 'D' capture"
  puts "       output.bin - destination file"
  exit
end

results = []

def parse_line (line)
  line.gsub!(/COMPLETE/, '')
  line.strip!
  return if line.length < 5
  line[5..-1].split(' ').collect { |str| str.hex }
end

File.readlines(ARGV[0]).drop(1).each do |line|
  results << parse_line(line)
end

results.compact!
results.flatten!

File.open(ARGV[1], 'wb' ) do |output|
    output.write results.pack("C*")
end
