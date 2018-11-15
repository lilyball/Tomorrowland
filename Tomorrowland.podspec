Pod::Spec.new do |s|
  s.name         = "Tomorrowland"
  s.version      = "0.3.4"
  s.summary      = "Lightweight Promises for Swift and Obj-C"

  s.description  = <<-DESC
                   Tomorrowland is a lightweight Promise implementation for Swift and Obj-C that supports cancellation and strongly-typed errors.
                   DESC

  s.homepage     = "https://github.com/kballard/Tomorrowland"
  s.license      = { :type => "MIT", :file => "LICENSE-MIT" }

  s.author             = "Lily Ballard"
  s.social_media_url   = "https://twitter.com/LilyInTech"

  s.ios.deployment_target = "9.0"
  s.osx.deployment_target = "10.10"
  s.watchos.deployment_target = "2.0"
  s.tvos.deployment_target = "9.0"

  s.swift_version = '4.0'

  s.source       = { :git => "https://github.com/kballard/Tomorrowland.git", :tag => "v#{s.version}" }

  project_headers = Dir['Sources/ObjC/*Private.h'] + ['Sources/ObjC/objc_cast.h']
  s.source_files  = Dir['Sources/**/*.{h,m,mm,swift}'] - project_headers
  s.private_header_files = 'Sources/Private/*.h'
  s.preserve_paths = project_headers

  s.library      = 'c++'

  s.module_map = "Sources/tomorrowland.modulemap"
end
