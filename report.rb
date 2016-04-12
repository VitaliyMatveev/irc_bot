class Report
  PADDING = 2
  def initialize(data)
    @data = data
    @columns_width = @data[0].keys.map {|col| col_width col}
    @width = @columns_width.reduce(:+)+PADDING*@data[0].keys.count*2 + @data[0].keys.count+1 #borders
  end

  def print
    print_border
    print_line @data[0].keys
    print_border
    @data.each do |row|
      print_line row.values
    end
    print_border
  end
  private
    def col_width col
      @data.reduce(0) do |width, item|
        width = width > item[col.to_sym].length ? width : item[col.to_sym].length
      end
    end

    def print_border
      puts "-"*@width
    end

    def get_cell text, width
      " "*PADDING + text.to_s + " "*(width-text.length) + " "*PADDING
    end
    def print_line columns
      line = "|"
      columns.each_with_index do |col, index|
        line+= get_cell(col, @columns_width[index])+"|"
      end
      puts line
    end
end
