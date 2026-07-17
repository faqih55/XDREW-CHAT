require 'xcodeproj'

project_path = 'XDREWiOS.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Add package dependency
package_url = "https://github.com/AgoraIO/AgoraRtcEngine_iOS.git"
pkg_ref = project.root_object.package_references.find { |p| p.repositoryURL == package_url }
unless pkg_ref
  pkg_ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  pkg_ref.repositoryURL = package_url
  pkg_ref.requirement = { "kind" => "upToNextMajorVersion", "minimumVersion" => "4.0.0" }
  project.root_object.package_references << pkg_ref
end

# Add product reference to target
unless target.package_product_dependencies.find { |p| p.product_name == "AgoraRtcKit" }
  pkg_prod_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  pkg_prod_dep.product_name = "AgoraRtcKit"
  pkg_prod_dep.package = pkg_ref
  target.package_product_dependencies << pkg_prod_dep
end

project.save
