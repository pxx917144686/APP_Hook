import Foundation
import StoreKit

// StoreKit 2 权限检查
@available(iOS 15.0, *)
class StoreKit2EntitlementHook: NSObject {
    
    // 实现 Hook 协议所需的属性
    typealias T = @convention(c) () -> Void
    var cls: AnyClass? { return NSClassFromString("StoreKit.Transaction") }
    var sel: Selector { return NSSelectorFromString("currentEntitlements") }
    var replace: T { return { print("[SatellaJailed] StoreKit2 Hook") } }
    
    func hook() {
        hookEntitlementChecks()
        hookSubscriptionStatus()
        hookProductSubscriptionInfo()
    }
    
    private func hookEntitlementChecks() {
        guard let transactionClass = NSClassFromString("StoreKit.Transaction") else { return }
        
        // Hook currentEntitlements 属性访问
        swizzleMethod(
            class: transactionClass,
            originalSelector: NSSelectorFromString("currentEntitlements"),
            swizzledSelector: #selector(hookedCurrentEntitlements)
        )
        
        // Hook verificationResult 方法 用于验证交易的真实性
        swizzleMethod(
            class: transactionClass,
            originalSelector: NSSelectorFromString("verificationResult"),
            swizzledSelector: #selector(hookedVerificationResult)
        )
    }
    
    private func hookSubscriptionStatus() {
        guard let _ = NSClassFromString("StoreKit.Product") else { return }
        guard let subscriptionInfoClass = NSClassFromString("StoreKit.Product.SubscriptionInfo") else { return }
        
        // Hook 订阅状态检查
        swizzleMethod(
            class: subscriptionInfoClass,
            originalSelector: NSSelectorFromString("subscriptionGroupID"),
            swizzledSelector: #selector(hookedSubscriptionGroupID)
        )
        
        // Hook 续费状态
        swizzleMethod(
            class: subscriptionInfoClass,
            originalSelector: NSSelectorFromString("renewalInfo"),
            swizzledSelector: #selector(hookedRenewalInfo)
        )
    }
    
    private func hookProductSubscriptionInfo() {
        guard let _ = NSClassFromString("StoreKit.Product") else { return }
        guard let subscriptionInfoClass = NSClassFromString("StoreKit.Product.SubscriptionInfo") else { return }
        
        // Hook 试用资格检查
        swizzleMethod(
            class: subscriptionInfoClass,
            originalSelector: NSSelectorFromString("isEligibleForIntroOffer"),
            swizzledSelector: #selector(hookedIsEligibleForIntroOffer)
        )
        
        // Hook 订阅期限检查
        swizzleMethod(
            class: subscriptionInfoClass,
            originalSelector: NSSelectorFromString("subscriptionPeriod"),
            swizzledSelector: #selector(hookedSubscriptionPeriod)
        )
    }
    
    // Swizzling 方法    
    private func swizzleMethod(class targetClass: AnyClass, originalSelector: Selector, swizzledSelector: Selector) {
        guard let originalMethod = class_getInstanceMethod(targetClass, originalSelector),
              let swizzledMethod = class_getInstanceMethod(type(of: self), swizzledSelector) else {
            return
        }
        
        let didAddMethod = class_addMethod(
            targetClass,
            originalSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )
        
        if didAddMethod {
            class_replaceMethod(
                targetClass,
                swizzledSelector,
                method_getImplementation(originalMethod),
                method_getTypeEncoding(originalMethod)
            )
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }

    // Hook方法实现
    @objc private func hookedCurrentEntitlements() -> Any {
        print("[SatellaJailed] 拦截到currentEntitlements调用")
        return createFakeEntitlementCollection()
    }
    
    @objc private func hookedVerificationResult() -> Any {
        print("[SatellaJailed] 拦截到verificationResult调用")
        return createVerifiedResult()
    }
    
    @objc private func hookedSubscriptionGroupID() -> String {
        print("[SatellaJailed] 返回伪造的订阅组ID")
        return "premium_subscription_group"
    }
    
    @objc private func hookedRenewalInfo() -> Any? {
        print("[SatellaJailed] 返回伪造的续费信息")
        return createMockRenewalInfo()
    }
    
    @objc private func hookedIsEligibleForIntroOffer() -> Bool {
        print("[SatellaJailed] 返回试用资格: true")
        return true
    }
    
    @objc private func hookedSubscriptionPeriod() -> Any? {
        print("[SatellaJailed] 返回年度订阅期限")
        return createMockSubscriptionPeriod()
    }
    
    // 辅助方法    
    private func createFakeEntitlementCollection() -> Any {
        return NSObject()
    }
    
    private func createVerifiedResult() -> Any {
        return NSObject()
    }
    
    private func createMockRenewalInfo() -> Any {
        return NSObject()
    }
    
    private func createMockSubscriptionPeriod() -> Any {
        return NSObject()
    }
}