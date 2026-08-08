import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    MacFilePanels.register(with: flutterViewController.engine.binaryMessenger)
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
    }

    super.awakeFromNib()
  }
}

/// Natív (runModal alapú) fájlpárbeszédablakok a file_selector sheet-je
/// helyett. A vezérlőablakhoz csatolt sheet a vetítőablak jelenlétében nem
/// jelenik meg megbízhatóan; a modális panel ettől függetlenül mindig a
/// felszínre kerül.
enum MacFilePanels {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "diatar/macos_file_panels",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      handle(call, result: result)
    }
  }

  private static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = (call.arguments as? [String: Any]) ?? [:]
    switch call.method {
    case "savePanel":
      let panel = NSSavePanel()
      if let name = args["suggestedName"] as? String {
        panel.nameFieldStringValue = name
      }
      if let directoryPath = args["directoryPath"] as? String, !directoryPath.isEmpty {
        panel.directoryURL = URL(fileURLWithPath: directoryPath)
      }
      if let prompt = args["prompt"] as? String {
        panel.prompt = prompt
      }
      if let extensions = args["extensions"] as? [String], !extensions.isEmpty {
        applyAllowedTypes(extensions, to: panel)
      }
      result(panel.runModal() == .OK ? panel.url?.path : nil)

    case "openPanel":
      let panel = NSOpenPanel()
      panel.canChooseFiles = true
      panel.canChooseDirectories = false
      panel.allowsMultipleSelection = (args["multiple"] as? Bool) ?? false
      if let directoryPath = args["directoryPath"] as? String, !directoryPath.isEmpty {
        panel.directoryURL = URL(fileURLWithPath: directoryPath)
      }
      if let extensions = args["extensions"] as? [String], !extensions.isEmpty {
        applyAllowedTypes(extensions, to: panel)
      }
      result(panel.runModal() == .OK ? panel.urls.map { $0.path } : [])

    case "directoryPanel":
      let panel = NSOpenPanel()
      panel.canChooseFiles = false
      panel.canChooseDirectories = true
      panel.allowsMultipleSelection = false
      if let directoryPath = args["directoryPath"] as? String, !directoryPath.isEmpty {
        panel.directoryURL = URL(fileURLWithPath: directoryPath)
      }
      result(panel.runModal() == .OK ? panel.url?.path : nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func applyAllowedTypes(_ extensions: [String], to panel: NSSavePanel) {
    if #available(macOS 11, *) {
      panel.allowedContentTypes = extensions.compactMap { UTType(filenameExtension: $0) }
    } else {
      panel.allowedFileTypes = extensions
    }
  }
}
