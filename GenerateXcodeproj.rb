#!/usr/bin/ruby

require 'xcodeproj'

puts "Generating Xcode project using SPM"
system "swift package generate-xcodeproj"

puts "Opening generated xcodeproj"
path_to_project = "MongoKitten.xcodeproj"
project = Xcodeproj::Project.open(path_to_project)

puts "Adding additional files to project"
readme_reference = project.main_group.new_reference("README.md")
project.main_group.children.move(readme_reference, 0)

if File.exists?("MongoKitten.playground")
    puts "Adding playground to project"
    project.main_group.new_reference("MongoKitten.playground")
end

config_group = project.new_group("Configuration files and scripts")

Dir.foreach('.') do |item|
    if item.end_with? ".md" and item != "README.md"
        item_reference = project.main_group.new_reference(item)
        project.main_group.children.move(item_reference, 1) # Move markdown files to the top, after the readme
    elsif item.end_with? ".rb" or item.end_with? ".sh" or item.end_with? ".yml" or item.end_with? ".yaml" or item.end_with? ".json"
        config_group.new_reference(item)
    end
end

puts "Adding build phases"

target = project.targets.select { |target| target.name == 'MongoKitten' }.first

# Add script phase for Sourcery
phase = target.new_shell_script_build_phase()
phase.name = "Codegen"
phase.shell_script = "./Codegen.sh"
target.build_phases.move(phase, 0) # Codegen must happen before compilation

# Add script phase for SwiftLint
phase = target.new_shell_script_build_phase()
phase.name = "SwiftLint"
phase.shell_script = <<-SCRIPT
if which swiftlint >/dev/null; then
    swiftlint
else
    echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
SCRIPT

project.save()

puts "Done"
