Pod::Spec.new do |s|
  s.name             = 'xstream_player'
  s.version          = '1.0.0'
  s.summary          = 'A new flutter plugin project.'
  s.description      = <<-DESC
Advanced video player for Flutter, based on video_player and inspired by Chewie and Better Player. 
It solves many common use cases out of the box and is easy to integrate.
                       DESC
  s.homepage         = 'https://github.com/SunnatilloShavkatov/betterplayer.git'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Sunnatillo Shavkatov' => 'sunnatillo.shavkatov@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'Cache', '~> 6.0.0'
  s.dependency 'GCDWebServer'
  s.dependency 'HLSCachingReverseProxyServer'
  s.dependency 'PINCache'
  s.dependency 'mamba', '~> 2.2.1'
  
  s.platform = :ios, '13.0'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
end 