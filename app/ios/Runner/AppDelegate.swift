import Flutter
import LocalAuthentication
import NetworkExtension
import Security
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
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let r = engineBridge.pluginRegistry.registrar(forPlugin: "NexVaultNative") {
      NexVaultNative.register(with: r)
    }
  }
}

/// iOS side of the `nexvault/native` channel (Android: MainActivity.kt).
///
/// Vault-key custody matches Android: with Face ID / Touch ID enabled, the key sits in a
/// Keychain item bound to the current biometric set (`.biometryCurrentSet`, this device only,
/// requires a passcode). After a successful scan Swift moves the bytes straight into the Rust
/// core (`nv_open_with_key` / `nv_check_key`) and wipes its buffer; Dart never sees the key.
///
/// Screen privacy: iOS cannot block screenshots like FLAG_SECURE, so the app covers its window
/// whenever it leaves the foreground (app switcher snapshot) and while the screen is recorded,
/// mirrored or AirPlayed.
final class NexVaultNative: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private var channel: FlutterMethodChannel?
  private var joinedSsid: String? // the other phone's Wi-Fi, joined for one pairing/sync
  private var pendingLink: String?
  // auth prompt buttons, in the app language (setLabels)
  private var labelUsePin = "Use PIN"
  private var labelCancel = "Cancel"
  private weak var window: UIWindow?
  private var cover: UIView?
  private var inactive = false

  private static let service = "vn.dsai.nexvault.bio"

  /// Two seals of the vault key, as on Android:
  ///   dev: Face ID / Touch ID or the device passcode (`.userPresence`), the default custody;
  ///        the passcode is throttled by the Secure Enclave.
  ///   bio: biometrics only (`.biometryCurrentSet`), next to an app PIN.
  struct Seal {
    let dev: Bool
    var account: String { dev ? "vault-key-dev" : "vault-key" }
    var flags: SecAccessControlCreateFlags { dev ? .userPresence : .biometryCurrentSet }
    var policy: LAPolicy { dev ? .deviceOwnerAuthentication : .deviceOwnerAuthenticationWithBiometrics }
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let me = NexVaultNative()
    let ch = FlutterMethodChannel(name: "nexvault/native", binaryMessenger: registrar.messenger())
    me.channel = ch
    registrar.addMethodCallDelegate(me, channel: ch)
    registrar.addSceneDelegate(me)
    NotificationCenter.default.addObserver(
      me, selector: #selector(captureChanged), name: UIScreen.capturedDidChangeNotification, object: nil)
  }

  // MARK: - Method channel

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let k = Seal(dev: args["kind"] as? String == "dev")
    switch call.method {
    case "initialLink":
      result(pendingLink)
      pendingLink = nil
    case "bioAvailable":
      result(LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil))
    case "devAvailable":
      result(LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil))
    case "setLabels":
      labelUsePin = args["usePin"] as? String ?? labelUsePin
      labelCancel = args["cancel"] as? String ?? labelCancel
      result(nil)
    case "deviceName":
      result(Self.deviceName())
    case "printHtml":
      // Rendered in memory by the print system; the app writes no file.
      let pic = UIPrintInteractionController.shared
      let info = UIPrintInfo(dictionary: nil)
      info.jobName = "NexVault"
      info.outputType = .general
      pic.printInfo = info
      pic.printFormatter = UIMarkupTextPrintFormatter(markupText: args["html"] as? String ?? "")
      pic.present(animated: true) { _, done, _ in result(done) }
    case "bioEnabled":
      result(Self.sealExists(k))
    case "bioEnroll":
      bioEnroll(k, title: args["title"] as? String ?? "NexVault", result: result)
    case "bioUnlock":
      let dir = args["dir"] as? String ?? ""
      withUnsealedKey(k, title: args["title"] as? String ?? "NexVault", result: result) { key in
        let p = key.withUnsafeBufferPointer { nv_open_with_key(dir, $0.baseAddress, UInt($0.count)) }
        defer { nv_free(p) }
        result(p.map { String(cString: $0) })
      }
    case "bioCheck":
      withUnsealedKey(k, title: args["title"] as? String ?? "NexVault", result: result) { key in
        result(key.withUnsafeBufferPointer { nv_check_key($0.baseAddress, UInt($0.count)) } == 1)
      }
    case "bioClear":
      Self.deleteSeal(k)
      result(nil)
    case "netIfaces":
      result(Self.netIfaces())
    case "hotspotSupported":
      // apps cannot start a hotspot on iOS; Personal Hotspot is the user's switch
      result(false)
    case "wifiJoin":
      // Join the other phone's private Wi-Fi for this session only (iOS asks the user first).
      let cfg = NEHotspotConfiguration(
        ssid: args["ssid"] as? String ?? "", passphrase: args["pass"] as? String ?? "", isWEP: false)
      cfg.joinOnce = true
      NEHotspotConfigurationManager.shared.apply(cfg) { err in
        if let e = err as NSError?, !(e.domain == NEHotspotConfigurationErrorDomain
          && e.code == NEHotspotConfigurationError.alreadyAssociated.rawValue) {
          let denied = e.domain == NEHotspotConfigurationErrorDomain
            && e.code == NEHotspotConfigurationError.userDenied.rawValue
          result(FlutterError(code: denied ? "denied" : "unavailable", message: e.localizedDescription, details: nil))
          return
        }
        self.joinedSsid = cfg.ssid
        result(true)
      }
    case "wifiLeave":
      if let s = joinedSsid { NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: s) }
      joinedSsid = nil
      result(nil)
    case "openAppSettings":
      if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
      result(nil)
    case "copySensitive":
      // local only (no Universal Clipboard to the user's Mac/iPad), and iOS drops it after 30 s
      UIPasteboard.general.setItems(
        [[UTType.utf8PlainText.identifier: args["text"] as? String ?? ""]],
        options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(30)])
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Biometric seal

  private static func baseQuery(_ k: Seal) -> [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
     kSecAttrService as String: service,
     kSecAttrAccount as String: k.account]
  }

  /// Since iOS 16 apps only get the generic "iPhone" / "iPad" as the device name (the name the
  /// user chose needs a restricted entitlement), so fall back to the marketing model name.
  private static func deviceName() -> String {
    let generic = UIDevice.current.model
    let n = UIDevice.current.name
    if n != generic { return n }
    var id = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? ""
    if id.isEmpty {
      var u = utsname()
      uname(&u)
      id = withUnsafeBytes(of: &u.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }
    return models[id] ?? generic
  }

  private static let models: [String: String] = [
    "iPhone12,1": "iPhone 11", "iPhone12,3": "iPhone 11 Pro", "iPhone12,5": "iPhone 11 Pro Max",
    "iPhone12,8": "iPhone SE", "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12",
    "iPhone13,3": "iPhone 12 Pro", "iPhone13,4": "iPhone 12 Pro Max", "iPhone14,4": "iPhone 13 mini",
    "iPhone14,5": "iPhone 13", "iPhone14,2": "iPhone 13 Pro", "iPhone14,3": "iPhone 13 Pro Max",
    "iPhone14,6": "iPhone SE", "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus",
    "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max", "iPhone15,4": "iPhone 15",
    "iPhone15,5": "iPhone 15 Plus", "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
    "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus", "iPhone17,1": "iPhone 16 Pro",
    "iPhone17,2": "iPhone 16 Pro Max", "iPhone17,5": "iPhone 16e",
    "iPad13,18": "iPad 10", "iPad13,19": "iPad 10", "iPad15,7": "iPad 11", "iPad15,8": "iPad 11",
    "iPad14,1": "iPad mini", "iPad14,2": "iPad mini", "iPad16,1": "iPad mini", "iPad16,2": "iPad mini",
    "iPad13,16": "iPad Air", "iPad13,17": "iPad Air",
  ]

  private static func sealExists(_ k: Seal) -> Bool {
    let ctx = LAContext()
    ctx.interactionNotAllowed = true
    var q = baseQuery(k)
    q[kSecUseAuthenticationContext as String] = ctx
    q[kSecReturnAttributes as String] = true
    let s = SecItemCopyMatching(q as CFDictionary, nil)
    return s == errSecSuccess || s == errSecInteractionNotAllowed
  }

  private static func deleteSeal(_ k: Seal) {
    SecItemDelete(baseQuery(k) as CFDictionary)
  }

  /// Face ID / Touch ID prompt. "Use PIN" (fallback) and cancel are reported as `cancel`.
  private func authenticate(_ k: Seal, _ title: String, _ done: @escaping (LAContext?, FlutterError?) -> Void) {
    let ctx = LAContext()
    // dev: iOS offers the device passcode itself; bio: the fallback goes to the app PIN
    if !k.dev { ctx.localizedFallbackTitle = labelUsePin }
    ctx.localizedCancelTitle = labelCancel
    ctx.evaluatePolicy(k.policy, localizedReason: title) { ok, err in
      DispatchQueue.main.async {
        if ok { return done(ctx, nil) }
        let code = (err as? LAError)?.code
        switch code {
        case .userCancel?, .userFallback?, .systemCancel?, .appCancel?:
          done(nil, FlutterError(code: "cancel", message: nil, details: nil))
        default:
          done(nil, FlutterError(code: "error", message: err?.localizedDescription, details: nil))
        }
      }
    }
  }

  private func bioEnroll(_ k: Seal, title: String, result: @escaping FlutterResult) {
    authenticate(k, title) { ctx, err in
      guard ctx != nil else { return result(err) }
      var key = [UInt8](repeating: 0, count: 32)
      defer { Self.wipe(&key) }
      guard nv_master_for_seal(&key) == 1 else {
        return result(FlutterError(code: "locked", message: "vault is locked", details: nil))
      }
      guard let ac = SecAccessControlCreateWithFlags(
        nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, k.flags, nil)
      else {
        return result(FlutterError(code: "seal_failed", message: "SecAccessControlCreateWithFlags failed", details: nil))
      }
      Self.deleteSeal(k)
      var q = Self.baseQuery(k)
      q[kSecAttrAccessControl as String] = ac
      q[kSecValueData as String] = Data(key)
      let s = SecItemAdd(q as CFDictionary, nil)
      if s == errSecSuccess {
        result(true)
      } else {
        // errSecMissingEntitlement / no passcode set
        result(FlutterError(code: "seal_failed", message: "SecItemAdd \(s)", details: nil))
      }
    }
  }

  /// Biometric prompt, then read the sealed key and hand it to `use` (wiped right after).
  private func withUnsealedKey(_ k: Seal, title: String, result: @escaping FlutterResult, use: @escaping ([UInt8]) -> Void) {
    guard Self.sealExists(k) else {
      return result(FlutterError(code: "not_enrolled", message: "no sealed key", details: nil))
    }
    authenticate(k, title) { ctx, err in
      guard let ctx = ctx else { return result(err) }
      var q = Self.baseQuery(k)
      q[kSecUseAuthenticationContext as String] = ctx
      q[kSecReturnData as String] = true
      var out: CFTypeRef?
      let s = SecItemCopyMatching(q as CFDictionary, &out)
      guard s == errSecSuccess, let data = out as? Data, data.count == 32 else {
        // bio: the biometric set changed since enrolment; dev: the passcode was removed
        Self.deleteSeal(k)
        return result(FlutterError(
          code: "invalidated", message: "key unreadable", details: nil))
      }
      var key = [UInt8](data)
      defer { Self.wipe(&key) }
      use(key)
    }
  }

  private static func wipe(_ b: inout [UInt8]) {
    b.withUnsafeMutableBufferPointer { p in
      if let a = p.baseAddress { memset_s(a, p.count, 0, p.count) }
    }
  }

  // MARK: - Network

  /// Interfaces peers can reach: Wi-Fi/Ethernet (en*), bridges (personal hotspot), the main
  /// cellular data context (pdp_ip0) and VPN tunnels. Skips the other pdp_ip* contexts
  /// (IMS/VoLTE and carrier services) that apps cannot use.
  private static func netIfaces() -> [String] {
    var head: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&head) == 0, let first = head else { return [] }
    defer { freeifaddrs(head) }
    var names = Set<String>()
    var p: UnsafeMutablePointer<ifaddrs>? = first
    while let i = p {
      let flags = Int32(i.pointee.ifa_flags)
      let fam = i.pointee.ifa_addr?.pointee.sa_family
      let name = String(cString: i.pointee.ifa_name)
      if flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0,
        fam == UInt8(AF_INET) || fam == UInt8(AF_INET6),
        name.hasPrefix("en") || name.hasPrefix("bridge") || name == "pdp_ip0" || name.hasPrefix("utun")
      {
        names.insert(name)
      }
      p = i.pointee.ifa_next
    }
    return Array(names).sorted()
  }

  // MARK: - Scene events: deep links and the privacy cover

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions?) -> Bool {
    window = (scene as? UIWindowScene)?.windows.first
    if let u = connectionOptions?.urlContexts.first?.url.absoluteString, u.hasPrefix("nexvault://") {
      pendingLink = u
    }
    return false
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    guard let u = URLContexts.first?.url.absoluteString, u.hasPrefix("nexvault://") else { return false }
    channel?.invokeMethod("link", arguments: u)
    return true
  }

  func sceneWillResignActive(_ scene: UIScene) {
    window = window ?? (scene as? UIWindowScene)?.windows.first
    inactive = true
    updateCover()
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    window = window ?? (scene as? UIWindowScene)?.windows.first
    inactive = false
    updateCover()
  }

  @objc private func captureChanged() { updateCover() }

  private func updateCover() {
    let captured = window?.windowScene?.screen.isCaptured ?? false
    if inactive || captured {
      guard cover == nil, let w = window else { return }
      let v = UIView(frame: w.bounds)
      v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      v.backgroundColor = UIColor(red: 0x17 / 255, green: 0x3D / 255, blue: 0x3A / 255, alpha: 1)
      let icon = UIImageView(image: UIImage(systemName: "lock.fill"))
      icon.tintColor = UIColor(red: 0xD4 / 255, green: 0xA9 / 255, blue: 0x4E / 255, alpha: 1)
      icon.contentMode = .scaleAspectFit
      icon.frame = CGRect(x: 0, y: 0, width: 56, height: 56)
      icon.center = CGPoint(x: w.bounds.midX, y: w.bounds.midY)
      icon.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
      v.addSubview(icon)
      w.addSubview(v)
      cover = v
    } else {
      cover?.removeFromSuperview()
      cover = nil
    }
  }
}
