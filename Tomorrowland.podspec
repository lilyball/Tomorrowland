Pod::Spec.new do |s|
  s.name         = "Tomorrowland"
  s.version      = "0.9"
  s.summary      = "Lightweight implementation of cancellable Promises for Swift"

  s.description  = <<-DESC
                   Tomorrowland is a lightweight Promise implementation for Swift that supports cancellation and strongly-typed errors.
                   DESC

  s.homepage     = "https://github.com/kballard/Tomorrowland"
  s.license      = { :type => "MIT", :file => "LICENSE-MIT" }

  s.author             = "Kevin Ballard"
  s.social_media_url   = "https://twitter.com/eridius"

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"
  s.watchos.deployment_target = "2.0"
  s.tvos.deployment_target = "9.0"

  s.source       = { :git => "https://github.com/kballard/Tomorrowland.git", :tag => "v#{s.version}" }
  s.source_files  = "Sources"
  s.private_header_files = "Sources/TWL*.h"

  s.module_map = "Sources/tomorrowland.modulemap"
end
