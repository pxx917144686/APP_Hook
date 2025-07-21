import Foundation

private struct _Preferences {
    func get<T>(
        for key: String,
        default val: T
    ) -> T {
        UserDefaults.standard.object(forKey: key) as? T ?? val
    }
}

private let prefs = _Preferences()

struct Preferences {
    static let isEnabled: Bool   = prefs.get(for: "tella_isEnabled",   default: true)
    static let isGesture: Bool   = prefs.get(for: "tella_isGesture",   default: true)
    static let isHidden: Bool    = prefs.get(for: "tella_isHidden",    default: false)
    static let isObserver: Bool  = prefs.get(for: "tella_isObserver",  default: false)
    static let isPriceZero: Bool = prefs.get(for: "tella_isPriceZero", default: false)
    static let isReceipt: Bool   = prefs.get(for: "tella_isReceipt",   default: false)
    static let isStealth: Bool   = prefs.get(for: "tella_isStealth",   default: false)
}

extension Preferences {
    // StoreKit 2 相关
    static var isStoreKit2Enabled: Bool {
        get { UserDefaults.standard.bool(forKey: "sk2_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "sk2_enabled") }
    }
    
    static var sk2ProductId: String {
        get { UserDefaults.standard.string(forKey: "sk2_product_id") ?? "premium.full.per.year" }
        set { UserDefaults.standard.set(newValue, forKey: "sk2_product_id") }
    }
    
    static var sk2ExpirationDate: String {
        get { UserDefaults.standard.string(forKey: "sk2_expiration") ?? "4092599349000" }
        set { UserDefaults.standard.set(newValue, forKey: "sk2_expiration") }
    }
}
