import AuthenticationServices
import Flutter
import UIKit

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
