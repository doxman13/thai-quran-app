import Flutter
import UIKit

// Force the linker to retain ONNX Runtime C API symbol for Dart FFI (onnxruntime_v2)
@_silgen_name("OrtGetApiBase")
@discardableResult
func OrtGetApiBase() -> UnsafeRawPointer?

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
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
  }
}
