require 'xcodeproj'

project_path = 'XDREWiOS.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group.find_subpath('XDREWiOS', true)
file_ref1 = group.new_file('AgoraManager.swift')
target.add_file_references([file_ref1])

file_ref2 = group.new_file('CallView.swift')
target.add_file_references([file_ref2])

project.save
