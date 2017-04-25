Pod::Spec.new do |s|
  s.name             = "YPImagePicker"
  s.version          = "1.0.0"
  s.summary          = "Instagram-like photo browser with a few line of code written in Swift"
  s.homepage         = "https://github.com/willks/YPImagePicker"
  s.license          = 'MIT'
  s.author           = { "ytakzk" => "blah@blahblahblah.com" }
  s.source           = { :git => "https://github.com/willks/YPImagePicker.git", :tag => s.version.to_s }
  
  s.platform     = :ios, '10.0'
  s.requires_arc = true
  s.source_files = 'Sources/**/*.swift'
  s.dependency  'SteviaLayout'
  s.resources    = ['Sources/Assets.xcassets', 'Sources/**/*.xib', 'Sources/**/Localizable.strings']
end
