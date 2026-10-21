import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    IosFilePanels.register(with: engineBridge.pluginRegistry)
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

/// Natív megnyitó párbeszédablak iOS-en.
///
/// A `file_selector` iOS implementációja a `UIDocumentPickerViewController`
/// felülérvényesítőjét az `UIApplicationDelegate.window` alapján keresi. A
/// `UISceneDelegate`-es életciklusban (amit ez az app is használ) az nincs
/// beállítva, ezért ott a megnyitás „Missing root view controller” hibával
/// elhasal. Itt a szín (scene) gyökerének root view kontrolleréből jelenítjük
/// meg a panelt.
///
/// Ugyanazt a csatornát és metódusnevet használja, mint a macOS-i
/// `MacFilePanels`, így a Dart oldal egyetlen hívóhelyen kezeli mindkettőt.
/// Mentésre és mappaválasztásra iOS-en nincs rendszerablak, a Dart oldal az
/// app export mappáját használja, ezért ezekre nincs esetkezelés.
enum IosFilePanels {
  private static let channelName = "diatar/macos_file_panels"
  private static let pickerDelegate = DocumentPickerDelegate()

  static func register(with pluginRegistry: FlutterPluginRegistry) {
    guard let registrar = pluginRegistry.registrar(forPlugin: channelName) else {
      return
    }
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      handle(call, result: result)
    }
  }

  private static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "openPanel":
      let args = (call.arguments as? [String: Any]) ?? [:]
      openPanel(args, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func openPanel(_ args: [String: Any], result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let presenter = presenter() else {
        result(
          FlutterError(
            code: "no_presenter",
            message: "Missing root view controller.",
            details: nil
          )
        )
        return
      }
      let extensions = (args["extensions"] as? [String]) ?? []
      // Ismeretlen kiterjesztésnél (pl. .dia, .dtx, .dtz) nincs bejelentett
      // rendszertípus, ilyenkor minden fájl választható és a Dart oldal
      // ellenőrzi a kiválasztott fájlt.
      var types = extensions.compactMap { UTType(filenameExtension: $0) }
      if types.isEmpty {
        types = [.data]
      }
      let panel = UIDocumentPickerViewController(
        forOpeningContentTypes: types,
        asCopy: true
      )
      panel.allowsMultipleSelection = (args["multiple"] as? Bool) ?? false
      pickerDelegate.result = { urls in
        result(urls.map { $0.path })
      }
      panel.delegate = pickerDelegate
      presenter.present(panel, animated: true)
    }
  }

  private static func presenter() -> UIViewController? {
    let windowScenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
    let scene = windowScenes.first { $0.activationState == .foregroundActive }
      ?? windowScenes.first
    var controller = (scene?.windows.first { $0.isKeyWindow }
      ?? scene?.windows.first)?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }
}

/// A megnyitó párbeszédablak eredményének átadása a Dart oldalnak.
final class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
  var result: (([URL]) -> Void)?

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    deliver(urls)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    deliver([])
  }

  private func deliver(_ urls: [URL]) {
    let handler = result
    result = nil
    handler?(urls)
  }
}
