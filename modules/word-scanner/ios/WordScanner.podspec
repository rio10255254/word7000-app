Pod::Spec.new do |s|
  s.name           = 'WordScanner'
  s.version        = '1.0.0'
  s.summary        = 'On-device text recognition for scanned vocabulary sheets'
  s.description    = 'Recognises English and Traditional Chinese text in a photo with Apple Vision.'
  s.author         = ''
  s.homepage       = 'https://docs.expo.dev/modules/'
  s.platforms      = {
    :ios => '15.1'
  }
  s.source         = { git: '' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'
  s.frameworks = 'Vision'

  # Swift/Objective-C compatibility
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }

  s.source_files = "**/*.{h,m,mm,swift,hpp,cpp}"
end
