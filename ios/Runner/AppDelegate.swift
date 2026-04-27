import Flutter
import GoogleMaps
import UIKit

@main
class AppDelegate: FlutterAppDelegate {
  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    if let mapsApiKey = Bundle.main.object(forInfoDictionaryKey: "GMSServicesAPIKey") as? String,
       !mapsApiKey.isEmpty,
       !mapsApiKey.hasPrefix("$(") {
      GMSServices.provideAPIKey(mapsApiKey)
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
