RSpec.describe XcodeArchiveCache::BuildGraph::NativeTargetFinder, "#find" do
  describe "valid searches" do
    before :each do
      @project = double("project")

      @first_native_target = double("first_native_target")
      @first_product_ref = double("first_product_ref")
      allow(@first_product_ref).to receive(:path).and_return("/some/path")
      allow(@first_native_target).to receive(:product_reference).and_return(@first_product_ref)
      allow(@first_native_target).to receive(:platform_name).and_return("platform")
      allow(@first_native_target).to receive(:test_target_type?).and_return(false)

      @second_native_target = double("second_native_target")
      @second_product_ref = double("second_product_ref")
      allow(@second_product_ref).to receive(:path).and_return("/some/other/path")
      allow(@second_native_target).to receive(:product_reference).and_return(@second_product_ref)
      allow(@second_native_target).to receive(:platform_name).and_return("platform")
      allow(@second_native_target).to receive(:test_target_type?).and_return(false)
    end

    describe "on file ref" do
      before :each do
        @file = double("file")
        @file_ref = double("file_ref")
        allow(@file_ref).to(receive(:is_a?)) {|klass| klass == Xcodeproj::Project::Object::PBXFileReference}
        allow(@file).to receive(:file_ref).and_return(@file_ref)
      end

      it "should correctly find target in root project" do
        allow(@project).to receive(:files).and_return([])
        allow(@project).to receive(:native_targets).and_return([@first_native_target, @second_native_target])
        allow(@file_ref).to receive(:path).and_return("/some/path")

        finder = XcodeArchiveCache::BuildGraph::NativeTargetFinder.new([@project])
        finder.set_platform_name_filter("platform")
        expect(finder.find_for_file(@file)).to eq(@first_native_target)
      end

      it "should correctly find target in nested project" do
        allow(@project).to receive(:native_targets).and_return([@first_native_target])

        nested_project_ref = double("nested_project_ref")
        allow(nested_project_ref).to receive(:path).and_return("nested.xcodeproj")
        allow(nested_project_ref).to receive(:real_path).and_return("nested.xcodeproj")
        allow(@project).to receive(:files).and_return([nested_project_ref])

        nested_project = double("nested_project")
        allow(nested_project).to receive(:native_targets).and_return([@second_native_target])
        allow(nested_project).to receive(:files).and_return([])

        allow(File).to receive(:exist?) {|file_path| file_path == "nested.xcodeproj"}
        allow(Xcodeproj::Project).to receive(:open) {|file_path| file_path == "nested.xcodeproj" ? nested_project : nil}

        allow(@file_ref).to receive(:path).and_return("/some/other/path")

        finder = XcodeArchiveCache::BuildGraph::NativeTargetFinder.new([@project])
        finder.set_platform_name_filter("platform")

        expect(finder.find_for_file(@file)).to eq(@second_native_target)
      end
    end

    describe "on reference proxy" do
      before :each do
        @file = double("file")

        @file_ref = double("file_ref")
        allow(@file_ref).to receive(:is_a?) {|klass| klass == Xcodeproj::Project::Object::PBXReferenceProxy}
        allow(@file).to receive(:file_ref).and_return(@file_ref)

        @remote_ref = double("remote_ref")
        allow(@remote_ref).to receive(:remote_global_id_string).and_return("product_uuid")
        allow(@file_ref).to receive(:remote_ref).and_return(@remote_ref)
      end

      it "should correctly find target in nested project" do
        allow(@project).to receive(:native_targets).and_return([@first_native_target])

        nested_project_ref = double("nested_project_ref")
        allow(nested_project_ref).to receive(:path).and_return("nested.xcodeproj")
        allow(nested_project_ref).to receive(:real_path).and_return("nested.xcodeproj")
        allow(@project).to receive(:files).and_return([nested_project_ref])

        nested_project = double("nested_project")
        product_reference = double("product_reference")
        allow(product_reference).to receive(:uuid).and_return("product_uuid")
        allow(@second_native_target).to receive(:product_reference).and_return(product_reference)
        allow(nested_project).to receive(:native_targets).and_return([@second_native_target])
        allow(nested_project).to receive(:files).and_return([])
        allow(@remote_ref).to receive(:container_portal_object).and_return(nested_project)

        allow(File).to(receive(:exist?)) {|file_path| file_path == "nested.xcodeproj"}
        allow(Xcodeproj::Project).to receive(:open) {|file_path| file_path == "nested.xcodeproj" ? nested_project : nil}

        finder = XcodeArchiveCache::BuildGraph::NativeTargetFinder.new([@project])
        finder.set_platform_name_filter("platform")

        expect(finder.find_for_file(@file)).to eq(@second_native_target)
      end
    end
  end
end