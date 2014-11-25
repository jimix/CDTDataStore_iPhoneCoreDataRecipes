source 'https://github.com/CocoaPods/Specs.git'
xcodeproj 'Recipes'

def import_pods
  pod "CDTDatastore", :path => "../CDTDatastore"
end

target :ios do
  platform :ios, '7.0'
  link_with 'Recipes'
  import_pods
end


