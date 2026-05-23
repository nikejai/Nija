import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let cloudBackupChannelName = "nija/cloud_backup"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: cloudBackupChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self else { return }
        if call.method == "backupToICloud" {
          guard
            let args = call.arguments as? [String: Any],
            let vaultId = args["vaultId"] as? String,
            let suggestedName = args["suggestedName"] as? String,
            let content = args["content"] as? String
          else {
            result(FlutterError(code: "bad_args", message: "Missing backup arguments", details: nil))
            return
          }
          result(self.backupToICloud(vaultId: vaultId, suggestedName: suggestedName, content: content))
          return
        }
        result(FlutterMethodNotImplemented)
      }
    }
    return ok
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func backupToICloud(vaultId: String, suggestedName: String, content: String) -> Bool {
    guard
      let ubiquityUrl = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
        .appendingPathComponent("Documents")
    else {
      return false
    }

    let safeVaultId = vaultId.replacingOccurrences(
      of: "[^A-Za-z0-9_-]",
      with: "_",
      options: .regularExpression
    )
    let fileManager = FileManager.default
    let vaultFolder = ubiquityUrl.appendingPathComponent("vaults").appendingPathComponent(safeVaultId)
    do {
      try fileManager.createDirectory(at: vaultFolder, withIntermediateDirectories: true)
      let latestFile = vaultFolder.appendingPathComponent("latest.nija")
      try content.write(to: latestFile, atomically: true, encoding: .utf8)

      let historyName = "\(Int(Date().timeIntervalSince1970))_\(suggestedName)"
      let historyFile = vaultFolder.appendingPathComponent(historyName)
      try content.write(to: historyFile, atomically: true, encoding: .utf8)
      return true
    } catch {
      return false
    }
  }
}
