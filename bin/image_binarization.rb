#! /usr/bin/env ruby

require 'trollop'
require 'ap'
require_relative '../lib/image'

opts = Trollop::options do
  version "image_binarization 0.0.1 (c) 2011 Vicente Bosch Campos"
  banner <<-EOS
image_binarization is a command tool to perform the Simple, Otsu's or Niblack's binarization on an input image and save the result to disk. The command tool
accepts as input and output format any format accepted by the Image Magick library.
Usage:
       image_binarization [options]
where [options] are:
EOS
  
  opt :mode, "Defines if the output must be displayed or saved to disk: file, screen", :type => :string, :default=>"screen"
  opt :input_image, "Path to image on which to perform the binarization", :type => :string
  opt :output_image, "Path where to save the image", :type => :string, :default => "./output.png"
  opt :algorithm, "Binarization algoritm to apply to the input image: simple,otsu,niblack", :type=> :string, :default => "simple"
  opt :niblack_region_size, "Size of the region: Height Width to apply on the Niblack calculation", :type => :ints, :default => [15,15]

end
#Defining special considerations for the entry data
Trollop::die :mode, "Execution mode must be: screen or file" unless ["screen","file"].include? opts[:mode]
Trollop::die :algorithm, "Binarization algorithm must be selected from: simple, otsu or niblack" unless ["simple","otsu","niblack"].include? opts[:algorithm]
Trollop::die :input_image, "Image path was not indicated" unless opts[:input_image]
Trollop::die :input_image, "Indicated image file does not exist" unless File.exist?(opts[:input_image])

opts[:algorithm]=(opts[:algorithm]+"_binarization").to_sym

img = Utils::Image.new(opts[:input_image])

if opts[:mode] == "screen"
  img.draw_binary_image(opts[:algorithm],*opts[:niblack_region_size])
elsif opts[:mode] == "file"
  img.save_binary_image(opts[:output_image],opts[:algorithm],opts[:niblack_region_size])
else
  puts "The execution mode indicated is not valid, only screen and file modes are valid"
end