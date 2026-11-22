# Adds the widget and watch targets to ios/Runner.xcodeproj (specs/017 research R4).
#
# Run once on macOS, by .github/workflows/ios-add-targets.yml (or `ruby tool/ios/add_widget_targets.rb`
# with the xcodeproj gem). It does nothing when the targets already exist. The sources it adds are
# written in the repository: ios/Shared, ios/MathaniWidgets, ios/MathaniWatch, ios/MathaniWatchWidgets.
require 'xcodeproj'

IOS = File.expand_path('../../ios', __dir__)
project = Xcodeproj::Project.open(File.join(IOS, 'Runner.xcodeproj'))

if project.targets.any? { |t| t.name == 'MathaniWidgets' }
  puts 'Widget targets already present; nothing to do.'
  exit 0
end

TEAM = 'YJBH85NYZU'
runner = project.targets.find { |t| t.name == 'Runner' } or abort 'No Runner target'
tests = project.targets.find { |t| t.name == 'RunnerTests' } or abort 'No RunnerTests target'

# A group for a folder of ios/, with a reference for each file in it (folders like .xcassets are
# single references).
def folder_group(project, name)
  group = project.main_group.new_group(name, name)
  Dir.children(File.join(IOS, name)).sort.each do |entry|
    next if entry.start_with?('.')
    ref = group.new_reference(entry)
    # String catalogs are compiled into each target's .strings files.
    ref.last_known_file_type = 'text.json.xcstrings' if entry.end_with?('.xcstrings')
  end
  group
end

shared = folder_group(project, 'Shared')
widgets_group = folder_group(project, 'MathaniWidgets')
watch_group = folder_group(project, 'MathaniWatch')
watch_widgets_group = folder_group(project, 'MathaniWatchWidgets')

def swift(group)
  group.files.select { |f| f.path.end_with?('.swift') }
end

def resources(group)
  group.files.select { |f| f.path.end_with?('.xcstrings', '.xcassets') }
end

# Runner's xcconfig per configuration (Flutter/Debug.xcconfig, Release.xcconfig), so
# $(FLUTTER_BUILD_NAME) and $(FLUTTER_BUILD_NUMBER) resolve in every target's Info.plist.
runner_configs = runner.build_configuration_list.build_configurations.map { |c| [c.name, c] }.to_h

def configure(target, runner_configs, bundle_id:, folder:, profile:, family:, extra: {})
  sdk = target.platform_name == :watchos ? 'watchos' : 'iphoneos'
  target.build_configurations.each do |config|
    base = runner_configs[config.name]&.base_configuration_reference
    config.base_configuration_reference = base if base
    s = config.build_settings
    s['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
    # xcodeproj leaves it empty, and every product would then be named ".app".
    s['PRODUCT_NAME'] = '$(TARGET_NAME)'
    # The Flutter template sets SUPPORTED_PLATFORMS = iphoneos for the project; without this the
    # watch widget extension would be built for iOS inside the iPhone build.
    s['SUPPORTED_PLATFORMS'] = 'watchos watchsimulator' if sdk == 'watchos'
    s['INFOPLIST_FILE'] = "#{folder}/Info.plist"
    s['GENERATE_INFOPLIST_FILE'] = 'NO'
    s['CODE_SIGN_ENTITLEMENTS'] = "#{folder}/#{folder}.entitlements"
    s['DEVELOPMENT_TEAM'] = TEAM
    s['SWIFT_VERSION'] = '5.0'
    s['TARGETED_DEVICE_FAMILY'] = family
    s['SKIP_INSTALL'] = 'YES'
    s['SUPPORTS_MACCATALYST'] = 'NO'
    s['ENABLE_BITCODE'] = 'NO'
    s['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
    extra.each { |k, v| s[k] = v }
    if config.name == 'Debug'
      s['CODE_SIGN_STYLE'] = 'Automatic'
    else
      # Store builds sign manually with the profiles the release workflow installs.
      s['CODE_SIGN_STYLE'] = 'Manual'
      s["CODE_SIGN_IDENTITY[sdk=#{sdk}*]"] = 'Apple Distribution'
      s['PROVISIONING_PROFILE_SPECIFIER'] = profile
    end
  end
end

# iPhone widget extension (iOS 15).
widgets = project.new_target(:app_extension, 'MathaniWidgets', :ios, '15.0')
configure(widgets, runner_configs, bundle_id: 'com.mthani.app.widgets', folder: 'MathaniWidgets',
          profile: 'Mathani Widgets App Store', family: '1,2',
          extra: { 'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks' })
widgets.add_file_references(swift(widgets_group) + swift(shared))
resources(widgets_group).each { |f| widgets.resources_build_phase.add_file_reference(f, true) }
%w[WidgetKit SwiftUI].each { |fw| widgets.add_system_framework(fw) }

# Watch app (watchOS 10), one screen (FR-021).
watch = project.new_target(:application, 'MathaniWatch', :watchos, '10.0')
configure(watch, runner_configs, bundle_id: 'com.mthani.app.watchkitapp', folder: 'MathaniWatch',
          profile: 'Mathani Watch App Store', family: '4',
          extra: { 'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
                   'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks' })
watch.add_file_references(swift(watch_group) + swift(shared))
resources(watch_group).each { |f| watch.resources_build_phase.add_file_reference(f, true) }

# Watch widget extension (complications and Smart Stack card).
watch_widgets = project.new_target(:app_extension, 'MathaniWatchWidgets', :watchos, '10.0')
configure(watch_widgets, runner_configs, bundle_id: 'com.mthani.app.watchkitapp.widgets',
          folder: 'MathaniWatchWidgets', profile: 'Mathani Watch Widgets App Store', family: '4',
          extra: { 'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks' })
watch_widgets.add_file_references(swift(watch_widgets_group) + swift(shared))
resources(watch_widgets_group).each { |f| watch_widgets.resources_build_phase.add_file_reference(f, true) }

# Embedding: the widget extension and the watch app in Runner, the watch widgets in the watch app.
def embed(host, product, name, spec, path = '')
  phase = host.new_copy_files_build_phase(name)
  phase.dst_subfolder_spec = spec
  phase.dst_path = path
  build_file = phase.add_file_reference(product, true)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  phase
end

runner.add_dependency(widgets)
runner.add_dependency(watch)
watch.add_dependency(watch_widgets)
embed_ext = embed(runner, widgets.product_reference, 'Embed Foundation Extensions', '13')
embed_watch = embed(runner, watch.product_reference, 'Embed Watch Content', '16', '$(CONTENTS_FOLDER_PATH)/Watch')
embed(watch, watch_widgets.product_reference, 'Embed Foundation Extensions', '13')

# Flutter's "Thin Binary" script must run after the embed phases, or Xcode reports a build cycle.
thin = runner.build_phases.find { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
if thin
  [embed_ext, embed_watch].each do |phase|
    runner.build_phases.delete(phase)
    runner.build_phases.insert(runner.build_phases.index(thin), phase)
  end
end

# The iPhone app's own new file, and the Swift tests of the shared code.
runner_group = project.main_group['Runner'] or abort 'No Runner group'
bridge = runner_group.files.find { |f| f.path == 'WidgetBridge.swift' } || runner_group.new_reference('WidgetBridge.swift')
runner.add_file_references([bridge])
tests_group = project.main_group['RunnerTests'] or abort 'No RunnerTests group'
new_tests = %w[WidgetSnapshotTests.swift PrayerTimelineTests.swift].map do |name|
  tests_group.files.find { |f| f.path == name } || tests_group.new_reference(name)
end
tests.add_file_references(new_tests + swift(shared))

project.save
puts 'Added MathaniWidgets, MathaniWatch and MathaniWatchWidgets.'
