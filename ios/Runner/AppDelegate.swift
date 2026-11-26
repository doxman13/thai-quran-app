import AuthenticationServices
import Flutter
import Photos
import UIKit

private final class SmartShareTextItemSource: NSObject, UIActivityItemSource {
  private let text: String

  init(text: String) {
    self.text = text
    super.init()
  }

  func activityViewControllerPlaceholderItem(
    _ activityViewController: UIActivityViewController
  ) -> Any {
    return text
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    itemForActivityType activityType: UIActivity.ActivityType?
  ) -> Any? {
    // Facebook and Instagram share extensions discard attached images when a URL/text
    // item is present, turning image shares into URL link previews.
    if let raw = activityType?.rawValue.lowercased(),
       raw.contains("facebook") || raw.contains("instagram") {
      return nil
    }
    return text
  }
}

// Force the linker to retain ONNX Runtime C API symbol for Dart FFI (onnxruntime_v2)
@_silgen_name("OrtGetApiBase")
@discardableResult
func OrtGetApiBase() -> UnsafeRawPointer?

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, ASWebAuthenticationPresentationContextProviding {
  private var activeAuthSession: ASWebAuthenticationSession?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Reference OrtGetApiBase so Apple linker doesn't drop static onnxruntime symbols
    _ = OrtGetApiBase()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let oauthChannel = FlutterMethodChannel(
      name: "com.thaiquran.app/oauth_session",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    oauthChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: "AppDelegate unavailable", details: nil))
        return
      }
      switch call.method {
      case "authenticate":
        self.handleAuthenticate(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let mediaShareChannel = FlutterMethodChannel(
      name: "com.thaiquran.app/media_share",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    mediaShareChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: "AppDelegate unavailable", details: nil))
        return
      }
      switch call.method {
      case "encodeJpeg":
        self.handleEncodeJpeg(call: call, result: result)
      case "copyImage":
        self.handleCopyImage(call: call, result: result)
      case "saveImage":
        self.handleSaveImage(call: call, result: result)
      case "shareImage":
        self.handleShareImage(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func handleEncodeJpeg(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let typedData = args["bytes"] as? FlutterStandardTypedData,
      let image = UIImage(data: typedData.data)
    else {
      result(FlutterError(code: "invalid_args", message: "Missing or invalid image bytes", details: nil))
      return
    }
    let qualityArg = args["quality"] as? Int ?? 95
    let quality = max(0.1, min(1.0, CGFloat(qualityArg) / 100.0))
    guard let jpeg = image.jpegData(compressionQuality: quality) else {
      result(FlutterError(code: "encode_failed", message: "Failed to encode JPEG", details: nil))
      return
    }
    result(FlutterStandardTypedData(bytes: jpeg))
  }

  private func handleCopyImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let typedData = args["bytes"] as? FlutterStandardTypedData,
      let image = UIImage(data: typedData.data)
    else {
      result(FlutterError(code: "invalid_args", message: "Missing or invalid image bytes", details: nil))
      return
    }

    DispatchQueue.main.async {
      UIPasteboard.general.image = image
      result(true)
    }
  }

  private func handleSaveImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let typedData = args["bytes"] as? FlutterStandardTypedData,
      let image = UIImage(data: typedData.data)
    else {
      result(FlutterError(code: "invalid_args", message: "Missing or invalid image bytes", details: nil))
      return
    }
    let fileName = (args["fileName"] as? String ?? "").lowercased()
    let saveAsJpeg = fileName.hasSuffix(".jpg") || fileName.hasSuffix(".jpeg")

    let saveToPhotoLibrary = {
      PHPhotoLibrary.shared().performChanges({
        if saveAsJpeg, let jpegData = image.jpegData(compressionQuality: 0.95) {
          let request = PHAssetCreationRequest.forAsset()
          request.addResource(with: .photo, data: jpegData, options: nil)
        } else {
          PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
      }) { success, error in
        DispatchQueue.main.async {
          if success {
            result(true)
          } else {
            result(FlutterError(
              code: "save_failed",
              message: error?.localizedDescription ?? "Failed to save image to photo library.",
              details: nil
            ))
          }
        }
      }
    }

    if #available(iOS 14, *) {
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        if status == .authorized || status == .limited {
          saveToPhotoLibrary()
        } else {
          DispatchQueue.main.async {
            result(FlutterError(
              code: "permission_denied",
              message: "Photo library permission denied.",
              details: nil
            ))
          }
        }
      }
    } else {
      PHPhotoLibrary.requestAuthorization { status in
        if status == .authorized {
          saveToPhotoLibrary()
        } else {
          DispatchQueue.main.async {
            result(FlutterError(
              code: "permission_denied",
              message: "Photo library permission denied.",
              details: nil
            ))
          }
        }
      }
    }
  }

  private func handleShareImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let filePath = args["filePath"] as? String,
      !filePath.isEmpty
    else {
      result(FlutterError(code: "invalid_args", message: "Missing filePath", details: nil))
      return
    }

    let text = args["text"] as? String
    let originX = args["originX"] as? Double
    let originY = args["originY"] as? Double
    let originWidth = args["originWidth"] as? Double
    let originHeight = args["originHeight"] as? Double

    let fileURL = URL(fileURLWithPath: filePath)
    var items: [Any] = [fileURL]
    if let text = text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      items.append(SmartShareTextItemSource(text: text))
    }

    DispatchQueue.main.async { [weak self] in
      guard let self = self, let presenter = self.topViewController() else {
        result(FlutterError(
          code: "no_presenter",
          message: "Unable to find active view controller to present share sheet.",
          details: nil
        ))
        return
      }

      let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
      if let popover = activityVC.popoverPresentationController {
        popover.sourceView = presenter.view
        let bounds = presenter.view.bounds
        let fallbackRect = CGRect(x: bounds.midX, y: bounds.midY, width: 1, height: 1)

        if let x = originX, let y = originY, let w = originWidth, let h = originHeight,
           w > 0, h > 0 {
          let globalRect = CGRect(x: x, y: y, width: w, height: h)
          let localRect = presenter.view.convert(globalRect, from: nil)
          if !localRect.isEmpty && bounds.intersects(localRect) {
            popover.sourceRect = localRect
          } else {
            popover.sourceRect = fallbackRect
          }
        } else {
          popover.sourceRect = fallbackRect
        }
      }

      var didComplete = false
      activityVC.completionWithItemsHandler = { _, completed, _, error in
        DispatchQueue.main.async {
          guard !didComplete else { return }
          didComplete = true
          if let error = error {
            result(FlutterError(
              code: "share_failed",
              message: error.localizedDescription,
              details: nil
            ))
          } else {
            result(completed ? "completed" : "dismissed")
          }
        }
      }

      presenter.present(activityVC, animated: true)
    }
  }

  private func topViewController() -> UIViewController? {
    let windowScenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
    let window = windowScenes
      .flatMap { $0.windows }
      .first(where: { $0.isKeyWindow })
      ?? windowScenes
        .filter { $0.activationState == .foregroundActive }
        .flatMap { $0.windows }
        .first
      ?? windowScenes.flatMap { $0.windows }.first

    var current = window?.rootViewController
    while let presented = current?.presentedViewController {
      current = presented
    }
    return current
  }

  private func handleAuthenticate(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let urlString = args["url"] as? String,
      let url = URL(string: urlString),
      let callbackScheme = args["callbackURLScheme"] as? String,
      !callbackScheme.isEmpty
    else {
      result(FlutterError(code: "invalid_args", message: "Missing url or callbackURLScheme", details: nil))
      return
    }

    let prefersEphemeral = args["prefersEphemeralWebBrowserSession"] as? Bool ?? false

    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: "AppDelegate unavailable", details: nil))
        return
      }

      if let existingSession = self.activeAuthSession {
        existingSession.cancel()
        self.activeAuthSession = nil
      }

      var didComplete = false
      var sessionRef: ASWebAuthenticationSession?
      let session = ASWebAuthenticationSession(
        url: url,
        callbackURLScheme: callbackScheme
      ) { [weak self] callbackURL, error in
        DispatchQueue.main.async {
          guard !didComplete else { return }
          didComplete = true

          if let self = self, let ref = sessionRef, self.activeAuthSession === ref {
            self.activeAuthSession = nil
          }

          if let callbackURL = callbackURL {
            result(callbackURL.absoluteString)
            return
          }

          if let authError = error as? ASWebAuthenticationSessionError,
             authError.code == .canceledLogin {
            result(FlutterError(
              code: "sign_in_canceled",
              message: "Sign-in was cancelled.",
              details: nil
            ))
            return
          }

          result(FlutterError(
            code: "oauth_session_failed",
            message: error?.localizedDescription ?? "Authentication session failed.",
            details: (error as NSError?)?.domain
          ))
        }
      }

      sessionRef = session
      session.presentationContextProvider = self
      session.prefersEphemeralWebBrowserSession = prefersEphemeral
      self.activeAuthSession = session

      if !session.start() {
        if !didComplete {
          didComplete = true
          if self.activeAuthSession === session {
            self.activeAuthSession = nil
          }
          result(FlutterError(
            code: "oauth_session_start_failed",
            message: "Unable to start authentication session.",
            details: nil
          ))
        }
      }
    }
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    let windowScenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
    if let keyWindow = windowScenes
      .flatMap({ $0.windows })
      .first(where: { $0.isKeyWindow }) {
      return keyWindow
    }
    if let activeWindow = windowScenes
      .filter({ $0.activationState == .foregroundActive })
      .flatMap({ $0.windows })
      .first {
      return activeWindow
    }
    if let anyWindow = windowScenes.flatMap({ $0.windows }).first {
      return anyWindow
    }
    return ASPresentationAnchor()
  }
}
