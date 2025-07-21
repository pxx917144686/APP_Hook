import UIKit

struct Tweak {
    static func ctor() {
        // StoreKit 1 hook
        CanPayHook().hook()
        DelegateHook().hook()
        TransactionHook().hook()
        
        if Preferences.isPriceZero { ProductHook().hook() }
        if Preferences.isObserver { ObserverHook().hook() }
        if Preferences.isStealth { DyldHook().hook() }
        
        if Preferences.isReceipt {
            ReceiptHook().hook()
            URLHook().hook()
        }
        
        // StoreKit 2 hook
        if #available(iOS 15.0, *) {
            if Preferences.isStoreKit2Enabled {
                StoreKit2FunctionHook.hookStoreKit2Methods()
                StoreKit2StorageHook().hook()
                StoreKit2EntitlementHook().hook()
            }
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
