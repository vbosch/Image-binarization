require 'extendmatrix'

class Matrix

  def normalize!(avg)   
     square=0.0
#     require 'ruby-debug'; debugger
     @rows.each do |row|
           row.each {|val| square+=(val-avg)**2}
      end
     deviation = Math.sqrt(square/(@rows.size*column_size).to_f)
     deviation = 1.0 if deviation == 0.0
     @rows.each_with_index do |row, row_index|
           row.each_with_index do |e, col_index|
             @rows[row_index][col_index] = (e - avg) / deviation
           end
     end
     return self
  end
  
  def to_histogram
    histogram = Hash.new
    histogram.default = 0
    @rows.each_with_index do |row, row_index|
      row.each_with_index do |e, col_index|
        histogram[e]+=1
      end
    end
    return histogram
  end
  
  def to_normalized_histogram
    histogram = Hash.new
    histogram.default = 0.0
    @rows.each_with_index do |row, row_index|
      row.each_with_index do |e, col_index|
        histogram[e]+=1.0
      end
    end
    num_elements = (row_size * column_size).to_f
    histogram.each do |index,value|
      histogram[index]/=num_elements
    end
    
    return histogram
  end
  
  def row_vector_accumulation!(row_index,v)
    @rows[row_index].size.times{|i| @rows[row_index][i] += v[i] }
    return self
  end
  
  def row_vector_decrement!(row_index,v)
    @rows[row_index].size.times{|i| @rows[row_index][i] -= v[i] }
    return self
  end
  def row_vector_scalar_division!(row_index,val)
    @rows[row_index].size.times{|i| @rows[row_index][i] /= val }
    return self
  end
  
  def row_vector_distance(row_index,v2)
    dist = 0.0
    @rows[row_index].size.times{|i|dist += (@rows[row_index][i]-v2[i])**2}
    return Math.sqrt(dist)
  end
  
  def to_elements
    elements = Array.new
    
    @rows.each_with_index do |row, row_index|
             elements.concat(@rows[row_index])
    end  
    return elements
  end
  
  
  def minor_to_elements(*param)
    case param.size
    when 2
      row_range, col_range = param
      from_row = row_range.first
      from_row += row_size if from_row < 0
      to_row = row_range.end
      to_row += row_size if to_row < 0
      to_row += 1 unless row_range.exclude_end?
      size_row = to_row - from_row

      from_col = col_range.first
      from_col += column_size if from_col < 0
      to_col = col_range.end
      to_col += column_size if to_col < 0
      to_col += 1 unless col_range.exclude_end?
      size_col = to_col - from_col
    when 4
      from_row, size_row, from_col, size_col = param
      return nil if size_row < 0 || size_col < 0
      from_row += row_size if from_row < 0
      from_col += column_size if from_col < 0
    else
      Matrix.Raise ArgumentError, param.inspect
    end

    return nil if from_row > row_size || from_col > column_size || from_row < 0 || from_col < 0
    
    elements = Array.new
    
    rows = @rows[from_row, size_row].each{|row|
      elements.concat(row[from_col, size_col])
    }
    return elements
  end
  
end

class Vector
      def calculate_distance(v2)
        dist = 0.0
        @elements.size.times{|i|dist += (@elements[i]-v2[i])**2}
        return Math.sqrt(dist)
      end
      
      def scalar_division!(val)
        (0...size).each{|i| @elements[i]/=val}
        return self
      end
      
      def minus_vector!(v)
        Vector.Raise ErrDimensionMismatch if size != v.size
        (0...size).each{|i| @elements[i]-=v[i]}
        return self
      end
      
      def minus_scalar!(val)
        (0...size).each{|i| @elements[i]-=val}
        return self
      end
end
