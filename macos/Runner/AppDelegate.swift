import Cocoa
import FlutterMacOS

/// Opening a design from the Finder.
///
/// macOS hands a double-clicked document to the app delegate, which can happen
/// before the Flutter engine exists -- on a cold launch it usually does. So the
/// path is held here and Dart asks for it once it is ready; anything arriving
/// later is pushed straight across. Without the holding step the first file a
/// user ever opens is the one that silently does nothing.
@main
class AppDelegate: FlutterAppDelegate {
  private static let channelName = "com.deadhat.remez/documents"

  private var channel: FlutterMethodChannel?
  private var pending: String?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: AppDelegate.channelName,
        binaryMessenger: controller.engine.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        // Dart calls this once it can act on a design; whatever the Finder
        // handed us before that is waiting here.
        if call.method == "takePending" {
          result(self?.pending)
          self?.pending = nil
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
      self.channel = channel
    }
    super.applicationDidFinishLaunching(notification)
  }

  private func deliver(_ path: String) {
    if let channel = channel {
      channel.invokeMethod("open", arguments: path)
    } else {
      pending = path
    }
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    guard let path = urls.first(where: { $0.isFileURL })?.path else { return }
    deliver(path)
  }

  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    deliver(filename)
    return true
  }
}
