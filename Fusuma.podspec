Pod::Spec.new do |s|
  s.name             = "Fusuma"
  s.version          = "0.1.3"
  s.summary          = "Instagram-like photo browser with a few line of code written in Swift"
  s.homepage         = "https://github.com/ytakzk/Fusuma"
  s.license          = 'MIT'
  s.author           = { "ytakzk" => "shyss.ak@gmail.com" }
  s.source           = { :git => "https://github.com/ytakzk/Fusuma.git", :tag => s.version.to_s }
  s.platform     = :ios, '8.0'
  s.requires_arc = true
  s.resource_bundles = {
    'Fusuma' => ['Classes/**/*']
  }

end