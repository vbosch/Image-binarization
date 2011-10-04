#! /usr/bin/env ruby

require 'trollop'
require 'ap'
require_relative '../lib/image'

opts = Trollop::options do
  version "connected_components 0.0.1 (c) 2011 Vicente Bosch Campos"
  banner <<-EOS
connected_components is a command tool to perform the calculation of the connected regions in a binary image.
Usage:
       connected_components [options]
where [options] are:
EOS
  
  opt :input_image, "Path to image on which to perform the connected regions calculation", :type => :string
  opt :output_image, "Path where to save the image if file mode is selected", :type => :string, :default => "./output.png"
  opt :neighbourhood, "Determines type of neighbourhood to apply for the continous region detection", :type=> :int, :default => 4
  opt :algorithm, "Binarization algoritm to apply to the input image: simple,otsu,niblack", :type=> :string, :default => "simple"
  opt :niblack_region_size, "Size of the region: Height Width to apply on the Niblack calculation", :type => :ints, :default => [15,15]  

end
#Defining special considerations for the entry data
Trollop::die :algorithm, "Binarization algorithm must be selected from: simple, otsu or niblack" unless ["simple","otsu","niblack"].include? opts[:algorithm]
Trollop::die :input_image, "Image path was not indicated" unless opts[:input_image]
Trollop::die :input_image, "Indicated image file does not exist" unless File.exist?(opts[:input_image])

opts[:algorithm]=(opts[:algorithm]+"_binarization").to_sym

img = Utils::Image.new(opts[:input_image])

img.binarize!(opts[:algorithm],*opts[:niblack_region_size])

img.detect_connected_regions(opts[:neighbourhood],opts[:output_image])