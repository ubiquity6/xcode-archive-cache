module XcodeArchiveCache
  module Build
    class ProductExtractor

      # @param [String] configuration
      # @param [String] derived_data_path
      #
      def initialize(configuration, derived_data_path)
        @configuration = configuration
        @derived_data_path = derived_data_path
        @shell_executor = XcodeArchiveCache::Shell::Executor.new
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] built_node
      #
      # @return [Array<String>]
      #
      def list_product_contents(built_node)
        file_paths = list_products(built_node)
        file_paths.select {|path| File.exist?(path)}.map {|path| File.realpath(path)}
      end

      private

      # @return [String]
      # 
      attr_reader :configuration

      # @return [String]
      #
      attr_reader :derived_data_path

      # @return [XcodeArchiveCache::Shell::Executor]
      #
      attr_reader :shell_executor

      # @param [XcodeArchiveCache::BuildGraph::Node] built_node
      #
      # @return [Array<String>]
      #
      def list_products(built_node)
        if built_node.has_framework_product?
          list_framework_products(built_node)
        elsif built_node.has_acceptable_product?
          list_single_product(built_node)
        else
          raise Informative, "#{built_node.name} has unsupported product type: #{built_node.native_target.product_type}"
        end
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] built_node
      #
      # @return [Array<String>]
      #
      def list_framework_products(built_node)
        framework_glob = get_main_product_glob(built_node)
        framework_path = Dir.glob(framework_glob).first
        unless framework_path
          raise Informative, "Framework product not found for #{built_node.name}"
        end

        framework_dsym_glob = File.join(File.dirname(framework_glob), built_node.dsym_file_name)
        framework_dsym_path = Dir.glob(framework_dsym_glob).first

        bc_symbolmap_paths = list_framework_bc_symbolmaps(framework_path)

        ([framework_path, framework_dsym_path] + bc_symbolmap_paths).flatten.compact
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] built_node
      #
      # @return [Array<String>]
      #
      def list_single_product(built_node)
        product_glob = get_main_product_glob(built_node)
        product_path = Dir.glob(product_glob).first
        unless product_path
          raise Informative, "Product of type #{built_node.native_target.product_type} not found for #{built_node.name}"
        end

        [product_path]
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] built_node
      #
      # @return [String]
      #
      def get_main_product_glob(built_node)
        product_name = built_node.native_target.product_reference.name ?
                           built_node.native_target.product_reference.name :
                           built_node.native_target.product_reference.path
        File.join(derived_data_path,
                  "**",
                  File.basename(product_name))
      end

      # @param [String] framework_path
      #
      # @return [Array<String>]
      #
      def list_framework_bc_symbolmaps(framework_path)
        executable_name = File.basename(framework_path, File.extname(framework_path))
        executable_path = File.join(framework_path, executable_name)
        unless File.exist?(executable_path)
          raise Informative, "Failed to find executable inside framework: #{framework_path}"
        end

        uuids = list_bc_symbolmap_uuids(executable_path)
        uuids.map {|uuid| find_bc_symbolmap(uuid)}.flatten
      end

      # @param [String] executable_path
      #
      # @return [Array<String>]
      #
      def list_bc_symbolmap_uuids(executable_path)
        shell_executor.execute_for_output("otool -l #{executable_path} | grep uuid | awk {'print $2'}").split("\n")
      end

      # @param [String] uuid
      #
      # @return [String]
      #
      def find_bc_symbolmap(uuid)
        Dir.glob(File.join(derived_data_path, "**", "#{uuid}.bcsymbolmap")).first
      end
    end
  end
end
