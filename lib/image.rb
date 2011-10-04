require 'RMagick'
require 'set'
require 'ap'
require 'ruby-debug'
require_relative '../lib/extendmatrix2'
require_relative '../lib/application_logger'

module Utils
  class Image
    
    def initialize(ex_path)
      @logger = Utils::ApplicationLogger.instance
      @logger.level = Logger::INFO
      @image_path = ex_path
      @logger.info("Loading image")
      @img = Magick::ImageList.new(@image_path)
      @intensity_matrix = obtain_image_intensity_matrix #obtains the gray channel of the image
      calculate_integral_images #generates the normal and sum of squares integral images
      @logger.info("Calculating normalized intensitiy histogram")
      @histogram = @intensity_matrix.to_normalized_histogram 
    end
    
    def image_rows
      return @img.rows
    end
    
    def image_columns
      return @image.columns
    end
    
    def mean_of_region(from_x=@integral_image.row_size-1,from_y=@integral_image.column_size-1,region_height=@integral_image.row_size-1,region_width=@integral_image.column_size-1)
      #if no parameters are given the input variables get assigned the default values indicated in the above specification and hence return the mean of the whole image
      #raise "Region size provided exceeds the image boundaries" if from_y - region_width < 0 or from_x - region_height < 0

=begin
      
      [1]-------[2] height + 1
       |         |
       |         |    basic formula is [4] - [2] - [3] + [1] but if [2] or [3] coincide with boundary size then 
       |         |    we do not have to delete the region beyond width or height ( as there is no region beyond)
       |         |    hence we do not have to add [1] to recover that corner section from being substracted twice
      [3]-------[4]
      width +1
=end      
    
      res = @integral_image[from_x,from_y]
      region_cuts = 0
      
      
      if from_y - region_width > 0
        res -= @integral_image[from_x,from_y-(region_width+1)]
        region_cuts+=1
      end
      
      if from_x - region_height > 0
        res -= @integral_image[from_x-(region_height+1),from_y]
        region_cuts+=1
      end
      
      if region_cuts == 2
        res += @integral_image[from_x-(region_height+1),from_y-(region_width+1)]
      end
      
      return res.to_f/(region_height*region_width).to_f
      
    end
    
    def standard_deviation_of_region(mean,from_x=@integral_image.row_size-1,from_y=@integral_image.column_size-1,region_height=@integral_image.row_size-1,region_width=@integral_image.column_size-1)
      #if no parameters are given the input variables get assigned the default values indicated in the above specification and hence return the deviation of the whole image
      #raise "Region size provided exceeds the image boundaries" if from_y - region_width < 0 or from_x - region_height < 0

      res = @sum_of_squares_intensity_matrix[from_x,from_y]
      region_cuts = 0

      if from_y - region_width > 0
        res -= @sum_of_squares_intensity_matrix[from_x,from_y-(region_width+1)]
        region_cuts+=1
      end

      if from_x - region_height > 0
        res -= @sum_of_squares_intensity_matrix[from_x-(region_height+1),from_y]
        region_cuts+=1
      end

      if region_cuts == 2
        res += @sum_of_squares_intensity_matrix[from_x-(region_height+1),from_y-(region_width+1)]
      end
      
      #region_width = region_width - from_y  if from_y - region_width < 0 
     # region_height = region_height - from_x if from_x - region_height < 0 
      
      return Math.sqrt(((res.to_f/(region_height*region_width).to_f)-mean**2).abs)

    end
    
    def obtain_image_intensity_matrix(img=@img)
      return Matrix.rows(img.export_pixels(0,0,img.columns,img.rows,"I").each_slice(img.columns).reduce([]) {|x,y| x<<y })
    end
    
    def intensity_matrix_to_image(intensity_matrix=@intensity_matrix)
      @logger.info("Transforiming intensity matrix to image")
      return Magick::Image.constitute(intensity_matrix.column_size, intensity_matrix.row_size,"I", intensity_matrix.to_elements)
    end
    
    def to_file(path,img=@img)
      @logger.info("Saving image to path: #{path}")
      img.write(path)
    end
    
    def calculate_integral_images(intensity_matrix=@intensity_matrix)
      @logger.info("Calculating integral images")
      res = intensity_matrix.clone
      res2= intensity_matrix.clone
      res.each_with_index do |val,x,y|
        res2[x,y]=res2[x,y]**2
        if x !=0 and y != 0
          res[x,y]+=res[x-1,y]+res[x,y-1]-res[x-1,y-1]
          res2[x,y]+=res2[x-1,y]+res2[x,y-1]-res2[x-1,y-1]
        elsif x ==0 and y != 0
          res[x,y]+=res[x,y-1]
          res2[x,y]+=res2[x,y-1]
        elsif x !=0 and y == 0
          res[x,y]+=res[x-1,y]
          res2[x,y]+=res2[x-1,y]
        end
      end
      @sum_of_squares_intensity_matrix = res2
      @integral_image = res
    end
    
    def apply_threshold(threshold=0.5,intensity_matrix=@intensity_matrix)
      threshold *= 255
      intensity_matrix.map{|val| val < threshold ? 0.0 : 1.0 }
    end
    
    def simple_binarization(intensity_matrix=@intensity_matrix,*params)
      #1. select initial estimate T (between mean gray value and (min+max)/2, depending on the expected area of the objects)
      median=(intensity_matrix.max+intensity_matrix.max)/2
      mean=mean_of_region #uses the method with integral image, no input params means default input params 
      threshold_old = Random.new.rand([mean,median].min..[mean,median].max)#selects a random value between the median and the mean
      threshold_new = threshold_old
      begin
        threshold_old = threshold_new
        mean_lower = 0; count_lower = 0 ; mean_higher = 0; count_higher = 0; 
        #2. compute average value μ1 of pixels > T and μ2 of pixels ≤ T 
        intensity_matrix.each do |val| 
          if val < threshold_old
            mean_lower+=val
            count_lower+=1.0
          else
            mean_higher+=val
            count_higher+=1.0
          end
        end
        
        mean_lower /= count_lower
        mean_higher /= count_higher
        
        #3. T ← (μ1 + μ2)/2
        threshold_new = (mean_lower + mean_higher) / 2
        
      end while (threshold_old - threshold_new).abs > 0.0001 #4. repeat from (2) until convergence
      
      threshold_new/=255.0
      
      return apply_threshold(threshold_new,intensity_matrix)
      
    end
    
    def otsu_binarization(intensity_matrix=@intensity_matrix,*params)
      
      percentage_calculated = 0
      csum=0.0
      sbmax=0.0
      threshold = -1
      sum = @histogram.inject(0.0){|res,(key,val)| res += key * val} #total sum of the histogram, in one line :-)
      @histogram.each do |key,value| 
        #we only visit the keys with values, hence we do not need to check if we have visited all filled buckets
        percentage_calculated += value.to_f
        percentage_pending = 1.0- percentage_calculated
        
        csum += (key * value).to_f
        m1 = csum / percentage_calculated.to_f
        m2 = (sum - csum) / percentage_pending.to_f
        sb = (percentage_calculated * percentage_pending *((m1 - m2)**2)).to_f
        if (sb > sbmax)
          sbmax = sb
          threshold = key
        end
      end
      threshold/=255.0
      return apply_threshold(threshold,intensity_matrix)
      
    end
    
    def niblack_binarization(intensity_matrix=@intensity_matrix,region_height=30,region_width=30)
      
      vec = intensity_matrix.each_with_index.map do |val,x,y|
        
        from_x = x+((region_height-1)/2) > intensity_matrix.row_size-1 ? intensity_matrix.row_size-1 : x+((region_height-1)/2)
        from_y = y+((region_width-1)/2) > intensity_matrix.column_size-1 ? intensity_matrix.column_size-1 : y+((region_width-1)/2)
        
        @logger.debug("Im on #{x} #{y} - region is going to start on #{from_x} #{from_y}")
        
        mean = mean_of_region(from_x,from_y,region_height,region_width).to_f
        
        threshold = (mean - 0.2 * standard_deviation_of_region(mean,from_x,from_y,region_height,region_width).to_f).to_f
        val < threshold ? 0.0 : 1.0 
      end
      
      return Matrix.rows(vec.each_slice(intensity_matrix.column_size).reduce([]) {|x,y| x += [y] })
      
    end
    
    def binarize!(method,*params)
      @logger.info("Performing #{method} binarization on image")
      @intensity_matrix = send(method,@intensity_matrix,*params)
      @logger.info("IMAGE CHANGED!! Recalculating internal representation")
      @img=intensity_matrix_to_image(@intensity_matrix)
      calculate_integral_images
      @histogram = @intensity_matrix.to_normalized_histogram
    end
    
    def draw_intensity_matrix(intensity_matrix=@intensity_matrix)
      @logger.info("Drawing intensity matrix")
      intensity_matrix_to_image(intensity_matrix).display
    end
    
    def draw_binary_image(method,*params)
      @logger.info("Performing #{method} binarization on image")
      bin_mat = send(method,@intensity_matrix,*params)
      draw_intensity_matrix(bin_mat)
    end
    
    def save_binary_image(path,method,*params)
      @logger.info("Performing #{method} binarization on image")
      bin_mat = send(method)
      to_file(path,intensity_matrix_to_image(bin_mat))
    end
    
    
    
    def detect_connected_regions(neighbourhood,output_file,intensity_matrix=@intensity_matrix)
      label_assignment_matrix = Matrix.build(intensity_matrix.row_size,intensity_matrix.column_size){0}
      labels_translation = Hash.new
      labels_translation[0]=0 #label of the empty regions
      @logger.info("Detecting connected regions")
      intensity_matrix.each_with_index do |val,x,y|
        
        next unless val.zero?        
        
        neighbour_labels = neighbour_labels_set(label_assignment_matrix,x,y,neighbourhood)
                
        if neighbour_labels.empty?
          new_label=labels_translation.keys.last+1
          labels_translation[new_label]=new_label
          label_assignment_matrix[x,y]=new_label
        else
          #we always assign the label with least number, so that level equivalence translation will be linear
          new_label=neighbour_labels.first
          label_assignment_matrix[x,y]=new_label
          neighbour_labels.each{|label| labels_translation[label]=new_label } if neighbour_labels.size > 1
        end
      end
      
      @logger.info("Translating region labels as per equivalence detected")
      labels_translation.each{|key,val|labels_translation[key]=labels_translation[val] if key != val}
      draw_connected_regions(extract_regions(label_assignment_matrix,labels_translation),output_file)
      
    end
    
    def neighbour_labels_set(label_assignment_matrix,x,y,neighbourhood)
      result = SortedSet.new
      
      result.add(label_assignment_matrix[x-1,y]) 
      result.add(label_assignment_matrix[x,y-1])
      
      if neighbourhood == 8
        result.add(label_assignment_matrix[x-1,y-1])
        result.add(label_assignment_matrix[x-1,y+1])         
      end
      
      result.delete(nil)
      result.delete(0)
      
      return result
    end
    
    def extract_regions(label_assignment_matrix,label_translation)
      @logger.info("Extracting regions to drawable format")
      regions= Hash.new{|h,key|h[key]=Array.new} #Array that will initialize an array for the key if not specified yet
      label_assignment_matrix.each_with_index do |val,x,y|
        unless label_translation[val].zero?
          region_target=label_translation[val]
          regions[region_target].push([y,x])
        end
      end
      
      return regions
    end
      
    def draw_connected_regions(region_list,output_file)
      @logger.info("Drawing regions")
      colors=["red","seagreen","royalblue","purple","sienna","steelblue","khaki","lightcoral","olive"]
      region_list.each_value do |region|
        gc = Magick::Draw.new 
        gc.stroke_width = 1
        gc.fill=colors.rotate![0]
        region.each do |point|       
          gc.point(point[0],point[1])  
        end
        gc.draw(@img)      
      end
      @img.display
      to_file(output_file,@img)
    end
    

    private :niblack_binarization , :otsu_binarization, :simple_binarization, :apply_threshold, :calculate_integral_images
  end
  

end