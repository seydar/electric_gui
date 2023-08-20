require 'glimmer-dsl-libui'

module GUI

  class Plotter
    include Glimmer

    attr_accessor :plot
    attr_accessor :margin
    attr_accessor :area

    def initialize(app, margin)
      @app    = app
      @margin = margin
    end

    def plot_info_box
      if @info
        case @info[:type]
        when :node; plot_node_info
        when :edge; plot_edge_info
        end
      end
    end

    def scale_area(area, plot)
      @area  = [area[:area_width], area[:area_height]]
      @scale = [area[:area_width]  / plot[0],
                area[:area_height] / plot[1]]
    end

    def select_info_box(x, y)
      @info   = @circles.find {|c| c[:circle].contain?(x, y) }
      @info ||= @edges.find {|e| e[:line].contain?(x,
                                                   y,
                                                   outline: true, 
                                                   distance_tolerance: 25) }
    end

    def plot_edge_info
      midpoint = [(@info[:from][0] + @info[:to][0]) / 2.0,
                  (@info[:from][1] + @info[:to][1]) / 2.0]
      rectangle(*midpoint, 200, 50) {
        stroke 0xff0000
        fill 0xd6d6d6
      }
      text(midpoint[0] + 5, midpoint[1] + 5) { string edge_info }
    end

    def plot_node_info
      rectangle(@info[:x], @info[:y], 160, 70) {
        stroke 0xff0000
        fill 0xd6d6d6
      }
      text(@info[:x] + 5, @info[:y] + 5) { string node_info }
    end

    def node_info
      ["Node Info",
       "ID: #{@info[:node].id}",
       "Load: #{@info[:node].load} MW",
       "Location: #{[(@info[:x] - @margin).round(2), (@info[:y] - @margin).round(2)]}"
       ].join "\n"
    end

    def edge_info
      ["Edge Info",
       "ID: #{@info[:edge].id}",
       @info[:edge].nodes.map(&:id).join(" <=> "),
       "Flow: #{@app.elec.flows[@info[:edge]].round 2}"
      ].join "\n"
    end

    def plot_flows(n: 10, scale: @scale, labels: nil)
      flows = @app.elec.flows || {}

      unless flows.empty?
        max, min = flows.values.max || 0, flows.values.min || 0
        splits = n.times.map {|i| (max - min) * i / n.to_f + min }
        splits = [*splits, [flows.values.max || 0, max].max + 1]

        # low to high, because that's how splits is generated
        percentiles = splits.each_cons(2).map do |bottom, top|
          flows.filter {|e, f| f >= bottom && f < top }.map {|e, f| e }
        end

        colors = BLUES.reverse + REDS
        percentiles.each.with_index do |pc, i|
          rhea = labels ? pc.map {|e| flows[e].round(2) } : []
          plot_edges pc, :color  => colors[((i + 1) * colors.size) / (n + 1)],
                         :width  => (i + 1 * 8.0 / n),
                         :labels => rhea,
                         :scale  => scale
        end
      end

      # Plot the untread edges to see if there are any even breaks in the grid
      edges = @app.elec.graph.nodes.map {|n| n.edges }.flatten.uniq
      untread = edges - flows.keys
      plot_edges untread, :scale => scale, :color => 0x00ffff

      plot_edges @app.congestion.added_edges, :scale => scale, :color => 0x18cf00, :width => 6.0

      plot_points scale: scale
      plot_generators scale: scale
    end

    def plot_edges(edges=nil, scale: @scale, color: 0x000000, width: 2, labels: [])
      edges ||= @app.elec.edges
      @edges = edges.zip(labels).map do |edge, label|
        plot_edge edge, scale: scale, color: color, width: width, label: label
      end
    end

    def plot_edge(edge, scale: @scale, color: 0x000000, width: 2, label: nil)
      from, to = *edge.nodes
      from = [@margin + from.x * scale[0], @margin + from.y * scale[1]]
      to   = [@margin + to.x * scale[0],   @margin + to.y * scale[1]]
      l = line(*from, *to) {
        stroke color, thickness: width
      }

      if label
        # TODO
      end

      {:edge => edge, :line => l, :from => from, :to => to, :type => :edge}
    end

    def plot_point(node, scale: @scale, color: {r: 202, g: 102, b: 205, a: 0.5})
      x = @margin + node.x * scale[0]
      y = @margin + node.y * scale[1]
      circ = circle(@margin + node.x * scale[0], @margin + node.y * scale[1], 3) {
        color.is_a?(Hash) ? fill(**color) : fill(color)
        stroke 0x000000, thickness: 2
      }
      {:node => node, :x => x, :y => y, :circle => circ, :type => :node}
    end

    def plot_points(points=nil, scale: @scale)
      points ||= @app.elec.nodes
      @circles = points.map do |node|
        plot_point node, scale: scale, color: 0xaaaaaa
      end
    end

    def plot_generators(scale: @scale)
      @app.elec.generators.each do |gen|
        plot_point gen.node, color: 0xff0000, scale: scale
      end
    end
  end
end

