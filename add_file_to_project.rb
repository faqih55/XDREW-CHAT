require 'xcodeproj'

project_path = 'XDREWiOS.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group.find_subpath('XDREWiOS', true)
file_ref = group.new_file('TypingIndicatorView.swift')
target.add_file_references([file_ref])

project.save
