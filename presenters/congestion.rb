require 'glimmer-dsl-libui'

module GUI

  class Congestion
    # FIXME code smell. not properly separating responsibilities
    include Glimmer

    attr_accessor :current_selection
    attr_accessor :added_edges
    attr_accessor :potential_edges

    Row = Struct.new :edges, :length, :tx_loss, :candidates

    def initialize(app)
      @app             = app
      @added_edges     = []
      @potential_edges = []
    end

    def refresh!
      if @current_selection
        cong = potential_edges[@current_selection]
        cong.candidates.each(&:detach!)
      end

      @current_selection = nil

      self.added_edges     = []
      self.potential_edges = []
    end

    # Also gets called when the table sort changes (since
    # `selection` is the index, and if the sort changes, then the
    # index changes, so this method is called)
    def select_reduction_option(selection)
      # Return early if no state change
      #   both nil
      #   selection isn't nil but refers to the same object
      return unless @current_selection || selection
      return if selection && @current_selection == potential_edges[selection]

      # Handle deselecting
      if @current_selection
        @current_selection.candidates.each(&:detach!)
      end

      # to cover base case of nothing selected
      @current_selection = selection

      # Handle selecting
      if selection
        @current_selection = potential_edges[selection]
        @current_selection.candidates.each(&:attach!)

        @added_edges = @current_selection.candidates
      else
        @added_edges = []
      end

      a = Time.now
      @app.elec.reset!
      puts "#{Time.now - a} to reset"

      @app.refresh!
    end

    def reduce_congestion(edge_limit=4)
      scale = @app.plotter.area.avg / 12
      new_edges = @app.elec.reduce_congestion :distance => 0.75 * scale

      # Hard ceiling on the edge length
      candidates = new_edges.map {|_, _, e, _| e.length < (0.5 * scale) ? e : nil }.compact
      candidates = candidates.uniq {|e| e.nodes.map(&:id).sort }

      # potentially thousands of trials to run
      # We're only interested in building up to `edge_limit` edges here, since
      # we're trying to show bang for buck
      trials = (1..edge_limit).map {|i| candidates.combination(i).to_a }.flatten(1)

      puts "\tMax # of edges to build: #{edge_limit}"
      puts "\t#{candidates.size} candidates, #{trials.size} trials"

      if not trials.empty?

        # Test out each combination.
        # Detaching the edges in another process is unnecessary since the grid object
        # is copied (and thus the main processes's grid is unaffected), but the code is
        # included because it's cheap and is required for single-threaded ops
        results = trials.parallel_map do |cands|
          cands.each {|e, _, _| e.attach! }
          @app.elec.reset!
          cands.each {|e, _, _| e.detach! }

          @app.elec.transmission_loss[1]
        end
        results = trials.zip results

        # minimize tx loss, minimize total edge length
        ranked = results.sort_by do |cs, l|
          l ** 1.35 + l * cs.sum(&:length)
        end

        puts "\tRanked them!"
        self.potential_edges = ranked.map do |cs, l|
          Row.new cs.size, cs.sum(&:length).round(2), l.round(2), cs
        end
      else
        puts "oh well"
        self.potential_edges = []
      end
    end
  end
end

