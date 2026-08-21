import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Von flutter_local_notifications verlangt. Ohne diese Zuweisung erscheint
    // eine Benachrichtigung nicht, solange die App im Vordergrund läuft, und
    // ein Tippen darauf erreicht die Dart-Seite nicht.
    //
    // Der optionale Cast statt einer festen Zuweisung stammt aus der Anleitung
    // des Plugins: FlutterAppDelegate erfüllt UNUserNotificationCenterDelegate
    // je nach Flutter-Version, und ein harter Cast bräche beim nächsten
    // Versionswechsel.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
