require 'histogram/array'
require 'glimmer-dsl-libui'

module GUI

  class Histogram
    include Glimmer

    X_OFF_LEFT   = 30
    Y_OFF_TOP    = 20
    X_OFF_RIGHT  = 20
    Y_OFF_BOTTOM = 40
    COLOR_BLUE   = Glimmer::LibUI.interpret_color(0x1E90FF)

    attr_accessor :hist_area

    def initialize(app)
      @app = app
    end

    def plot(area)
      scale_area area

      plot_frame
      plot_bars
      plot_title
      plot_axes
    end

    def graph_size(area_width, area_height)
      graph_width = area_width - X_OFF_LEFT - X_OFF_RIGHT
      graph_height = area_height - Y_OFF_TOP - Y_OFF_BOTTOM
      [graph_width, graph_height]
    end
    
    def scale_x(bins, width, bar_width)
      scale = (width - (1.25 * bar_width)) / bins.max
      bins.map do |bin|
        scale * bin
      end
    end

    def scale_y(freqs, height)
      peak = 0.75 # how much of the graph should the peak take up
      scale = height * peak / freqs.max
      freqs.map do |freq|

        # have to invert because the y axis is inverted from standard graphs
        # because that's how GUIs work
        height - freq * scale
      end
    end

    # God this code is so bad
    def bar_graph(data, width, height, bar_width, &block)

      path {
        bins, freqs = @app.elec.flows.values.histogram :bin_boundary => :min

        data.zip(bins.zip(freqs)).each do |(x, y), (bin, freq)|
          rectangle(x, y, bar_width, height - y)

          # X value labeling
          text(x + bar_width / 4 - 1, height + 3) { string bin.round(1).to_s }

          # Y value labeling
          text(x + bar_width / 4 - 1, y - 20) { string freq.to_i.to_s }
        end

        transform {
          translate X_OFF_LEFT, Y_OFF_TOP
        }

        block.call
      }
    end

    def scale_area(area)
      width, height = *graph_size(area[:area_width], area[:area_height])
      @hist_area = {:width => width, :height => height}
    end

    def plot_frame
      figure(X_OFF_LEFT, Y_OFF_TOP) {
        line(X_OFF_LEFT, Y_OFF_TOP + @hist_area[:height])
        line(X_OFF_LEFT + @hist_area[:width], Y_OFF_TOP + @hist_area[:height])
        
        stroke 0x000000, thickness: 2, miter_limit: 10
      }
    end

    def plot_bars
      if @app.elec.flows && !@app.elec.flows.empty?
        bins, freqs = @app.elec.flows.values.histogram
        bar_width = ((@hist_area[:width] / bins.size) * 0.8).floor

        bins  = scale_x bins, @hist_area[:width], bar_width
        freqs = scale_y freqs, @hist_area[:height]

        bar_graph(bins.zip(freqs), @hist_area[:width], @hist_area[:height], bar_width) {
          stroke COLOR_BLUE.merge(thickness: 2, miter_limit: 10)
          fill COLOR_BLUE.merge(a: 0.5)
        }
      end
    end

    def plot_title
      text(@hist_area[:width] / 2 - 2 * X_OFF_LEFT,
           Y_OFF_TOP / 2) {
        string "Histogram of Line Congestion"
      }
    end

    def plot_axes
      # X axis
      text(@hist_area[:width] / 2 - 2 * X_OFF_LEFT,
           @hist_area[:height] + Y_OFF_TOP + 17) {
        string "Congestion (MW through lines)"
      }

      # Y axis
      path {
        text(X_OFF_LEFT / 2,
             @hist_area[:height] / 2 + Y_OFF_TOP) {
          string "# of lines"
        }

        transform {
          rotate(X_OFF_LEFT / 2 + 2,
                 @hist_area[:height] / 2 + Y_OFF_TOP + 10,
                 -90)
        }
      }
    end
  end
end

