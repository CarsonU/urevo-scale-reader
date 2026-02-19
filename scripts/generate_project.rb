#!/usr/bin/env ruby

require 'fileutils'
require 'pathname'
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'UrevoScale.xcodeproj')

FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH)

app_target = project.new_target(:application, 'UrevoScale', :ios, '17.0')
test_target = project.new_target(:unit_test_bundle, 'UrevoScaleTests', :ios, '17.0')
test_target.add_dependency(app_target)

app_settings = {
  'PRODUCT_BUNDLE_IDENTIFIER' => 'com.carson.urevoscale',
  'INFOPLIST_FILE' => 'UrevoScale/Resources/Info.plist',
  'CODE_SIGN_STYLE' => 'Automatic',
  'SWIFT_VERSION' => '5.0',
  'IPHONEOS_DEPLOYMENT_TARGET' => '17.0',
  'GENERATE_INFOPLIST_FILE' => 'NO',
  'CODE_SIGN_ENTITLEMENTS' => 'UrevoScale/Resources/UrevoScale.entitlements',
  'ENABLE_USER_SCRIPT_SANDBOXING' => 'YES',
  'SWIFT_EMIT_LOC_STRINGS' => 'YES'
}

app_target.build_configurations.each do |config|
  app_settings.each do |key, value|
    config.build_settings[key] = value
  end
end

test_settings = {
  'PRODUCT_BUNDLE_IDENTIFIER' => 'com.carson.urevoscaleTests',
  'INFOPLIST_FILE' => 'UrevoScaleTests/Info.plist',
  'SWIFT_VERSION' => '5.0',
  'IPHONEOS_DEPLOYMENT_TARGET' => '17.0',
  'GENERATE_INFOPLIST_FILE' => 'NO',
  'CODE_SIGN_STYLE' => 'Automatic',
  'TEST_HOST' => '$(BUILT_PRODUCTS_DIR)/UrevoScale.app/UrevoScale',
  'BUNDLE_LOADER' => '$(TEST_HOST)'
}

test_target.build_configurations.each do |config|
  test_settings.each do |key, value|
    config.build_settings[key] = value
  end
end

app_group = project.main_group.new_group('UrevoScale', nil)
tests_group = project.main_group.new_group('UrevoScaleTests', nil)

relative = lambda do |path|
  Pathname.new(path).relative_path_from(Pathname.new(ROOT)).to_s
end

Dir.glob(File.join(ROOT, 'UrevoScale/**/*.swift')).sort.each do |file|
  ref = app_group.new_file(relative.call(file))
  app_target.add_file_references([ref])
end

app_group.new_file('UrevoScale/Resources/Info.plist')
app_group.new_file('UrevoScale/Resources/UrevoScale.entitlements')

Dir.glob(File.join(ROOT, 'UrevoScaleTests/**/*.swift')).sort.each do |file|
  ref = tests_group.new_file(relative.call(file))
  test_target.add_file_references([ref])
end
tests_group.new_file('UrevoScaleTests/Info.plist')

%w[CoreBluetooth.framework HealthKit.framework].each do |framework|
  ref = project.frameworks_group.new_file("System/Library/Frameworks/#{framework}")
  app_target.frameworks_build_phase.add_file_reference(ref, true)
end

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app_target)
scheme.add_test_target(test_target)
scheme.set_launch_target(app_target)
scheme.save_as(PROJECT_PATH, 'UrevoScale', true)

project.save
puts "Generated #{PROJECT_PATH}"
