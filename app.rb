#!/usr/bin/env ruby --yjit -W0

require_relative "../electric_avenue.rb"
require 'glimmer-dsl-libui'
Dir['./gui/presenters/*.rb'].each {|f| require f }

class GridApp
  include Glimmer
  include GUI

  MARGIN   = 10
  CONTROLS = 310
  PLOT     = [1000, 500]
  TABLE    = 200
  WIDTH    = TABLE + PLOT[0] + 4 * MARGIN
  HEIGHT   = CONTROLS + PLOT[1] + 4 * MARGIN

  attr_accessor :desc
  attr_accessor :elec
  attr_accessor :congestion
  attr_accessor :plotter
  attr_accessor :histogram

  def initialize
    # buttons
    # basic class of # nodes, # nodes per cluster, load per node
    @overall = Overall.new 800, 80, 10

    # basic info
    @elec = Grid.new [], []

    # plot
    @plotter = Plotter.new self, MARGIN

    # congestion reduction table
    @congestion = Congestion.new self

    # congestion histogram
    @histogram = Histogram.new self
  end

  def refresh!
    @plot.queue_redraw_all
    @hist.queue_redraw_all
    self.desc = grid_description
  end

  def grid_description
    tx_loss, perc = @elec.transmission_loss

    ["Grid range:\t#{@plotter.area[0]} x #{@plotter.area[1]}",
     "Nodes:\t\t#{@elec.nodes.size}",
     "Edges:\t\t#{@elec.edges.size}",
     "Total load:\t#{(@elec.loads.sum(&:load) + tx_loss).round 2}",
     "Tx loss:\t\t#{tx_loss.round 2} (#{perc}%)",
     "Freq:\t\t#{(Flow::BASE_FREQ + @elec.freq).round(2)} Hz (#{@elec.freq.round 2} Hz)"
    ].join "\n"
  end

  def launch
    window("Electric Avenue", WIDTH, HEIGHT, true) {
      margined true

      grid {

        new_grid_buttons x: 0, y: 1

        basic_info x: 0, xs: 2,
                   y: 4, ys: 1

        congestion_hist x: 2, xs: 2,
                        y: 0, ys: 6

        label { left 0; xspan 2
                top  5; yspan 1 }

        label { left 0; xspan 2
                top  5; yspan 1 }

        cong_reduc_table x: 0, xs: 1,
                         y: 6, ys: 3

        plot_area  x: 1, xs: 3,
                   y: 6, ys: 3
      }

    }.show
  end

  def congestion_hist(x: nil, y: nil, xs: 2, ys: 3)

    @hist = area {
      left x; xspan xs
      top  y; yspan ys
      vexpand true

      on_draw do |area|
        rectangle(0, 0, area[:area_width], area[:area_height]) {
          fill 0xFFFFFF
        }

        @histogram.plot area
      end
    }
  end

  def basic_info(x: nil, y: nil, xs: 4, ys: 1)
    label {
      left x; xspan xs
      top  y; yspan ys
      hexpand true

      text <=> [self, :desc]
    }
  end

  def new_grid_buttons(x: nil, y: nil)
    form {
      left x; xspan 1
      top  y; yspan 1

      entry {
        label 'Nodes'
        text <=> [@overall, :number, on_write: :to_i, on_read: :to_s]
      }
    }

    form {
      left (x + 1); xspan 1
      top   y     ; yspan 1
  
      entry {
        label 'Group By'
        text <=> [@overall, :group_by, on_write: :to_i, on_read: :to_s]
      }
    }

    form {
      left (x + 2); xspan 1
      top   y     ; yspan 1
    }

    form {
      left  x     ; xspan 1
      top  (y + 1); yspan 1
  
      entry {
        label 'MW load/node'
        text <=> [@overall, :load, on_write: :to_i, on_read: :to_s]
      }
    }

    button('New Grid') {
      left (x + 1); xspan 1
      top  (y + 1); yspan 1

      on_clicked {
        plot = PLOT
        range = [plot[0] - 2 * MARGIN, plot[1] - 2 * MARGIN]
        @elec = @overall.mst_grid :range => range
        @congestion.refresh!
        refresh!
      }
    } # button

    button("Reduce Congestion") {
      left (x + 1); xspan 1
      top  (y + 2); yspan 1

      on_clicked {
        LibUI::queue_main { @congestion.reduce_congestion }
      }
    }
  end

  def cong_reduc_table(x: nil, y: nil, xs: 1, ys: 2)
    table {
      left x; xspan xs
      top  y; yspan ys

      text_column "Edges"
      text_column "Length"
      text_column "Tx Loss"

      cell_rows <=> [@congestion, :potential_edges]

      on_selection_changed do |_, selection, _, _|
        @congestion.select_reduction_option selection
      end
    }
  end

  def plot_area(x: nil, y: nil, xs: 3, ys: 2)
    @plot = area {
      left x; xspan xs
      top  y; yspan ys

      on_draw {|area|
        @plotter.scale_area area, PLOT
        self.desc = grid_description

        # Background
        rectangle(0, 0, area[:area_width], area[:area_height]) {
          fill 0xffffff
        }

        # Graph
        @plotter.plot_flows

        # Info
        @plotter.plot_info_box
      }

      on_mouse_up do |area_event|
        @plotter.select_info_box(area_event[:x], area_event[:y])
        @plot.queue_redraw_all
      end
    }
  end
end

GridApp.new.launch

