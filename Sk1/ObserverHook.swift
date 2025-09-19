import StoreKit

struct ObserverHook: Hook {
    typealias T = @convention(c) (AnyObject, Selector, SKPaymentTransactionObserver) -> Void

    let cls: AnyClass? = SKPaymentQueue.self
    let sel: Selector = sel_registerName("addTransactionObserver:")
    let replace: T = { obj, sel, observer in
        let tella: SatellaObserver = .shared
        tella.observers.append(observer)
        Self.orig(obj, sel, tella)
    }
}
