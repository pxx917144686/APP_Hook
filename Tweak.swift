import UIKit

struct Tweak {
    static func ctor() {
        // 设置默认偏好设置
        Preferences.setupDefaults()
        // 初始化 Jinx 兼容层（iOS12-18 环境探测与日志）
        JinxCompat.bootstrap()
        
        // StoreKit 1 hook
        Sk1Hooks.bootstrap()
        
        if Preferences.isPriceZero { Sk1Hooks.priceZero() }
        if Preferences.isObserver { ObserverHook().hook() }
        if Preferences.isStealth { DyldHook().hook() }
        
        if Preferences.isReceipt {
            ReceiptHook().hook()
        }
        
        // StoreKit 2 hooks - 直接使用 URLHook
        if #available(iOS 15.0, *) {
            Sk2Hooks.bootstrap()
        }
        
        if #available(iOS 15, *) {
            if Preferences.isGesture {
                WindowHook().hook()
            }
            
            guard !Preferences.isHidden else {
                return
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                let rootVC: UIViewController?
                
                if #available(iOS 15.0, *) {
                    rootVC = UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .flatMap { $0.windows }
                        .first(where: { $0.isKeyWindow })?
                        .rootViewController
                } else {
                    rootVC = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
                }
                
                rootVC?.add(SatellaController.shared)
            }
        }
    }
}

@_cdecl("jinx_entry")
func jinx_entry() {
    Tweak.ctor()
}
