module GUI

  # TODO move this to lib/ so that it can be used by the CLI executables
  class Overall
    attr_accessor :number
    attr_accessor :group_by
    attr_accessor :load

    def initialize(number=800, group_by=80, drawing=10)
      @number   = number
      @group_by = group_by
      @load     = drawing
    end

    def mst_grid(range: [10, 10])
      nodes = @number.times.map do |i|
        n = Node.new(range[0] * PRNG.rand, range[1] * PRNG.rand, :id => i)
        n.load = @load
        n
      end

      pairs = nodes.combination 2
      edges = pairs.map.with_index do |(p_1, p_2), i|
        Edge.new p_1,
                 p_2,
                 p_1.euclidean_distance(p_2),
                 :id => i
      end

      mst = []

      # Builds edges between nodes according to the MST
      parallel_filter_kruskal edges, UnionF.new(nodes), mst

      # Give edges new IDs so that they are 0..|edges|
      edges = nodes.map(&:edges).flatten.uniq
      edges.each.with_index {|e, i| e.id = i }

      grid = Grid.new nodes, []

      # FIXME does this really need to be a separate graph?
      graph = ConnectedGraph.new grid.nodes

      # Needed for the global adjacency matrix for doing faster manhattan distance
      # calculations
      KMeansClusterer::Distance.graph = graph
      
      grid.build_generators_for_unreached @group_by

      grid
    end
  end
end

