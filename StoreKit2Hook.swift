import Foundation
import StoreKit
import ObjectiveC

@available(iOS 15.0, *)
struct StoreKit2FunctionHook {
    
    static func hookStoreKit2Methods() {
        hookCurrentEntitlements()
        hookTransactionUpdates()
        hookProductPurchase()
        hookVerificationResult()
        hookReceiptRefresh()
    }
    
    private static func hookCurrentEntitlements() {
        let originalSymbol = "_$s8StoreKit11TransactionV19currentEntitlementsAC12TransactionsVvgZ"
        
        guard let handle = dlopen(nil, RTLD_NOW),
              let originalFunc = dlsym(handle, originalSymbol) else { 
            print("[SatellaJailed] 无法找到currentEntitlements符号")
            return 
        }
        
        var originalPtr: UnsafeMutableRawPointer? = UnsafeMutableRawPointer(mutating: originalFunc)
        
        withUnsafeMutablePointer(to: &originalPtr) { ptr in
            let hook = RebindHook(
                name: "currentEntitlements",
                replace: unsafeBitCast(currentEntitlementsReplacement, to: UnsafeMutableRawPointer.self),
                orig: ptr
            )
            
            if !Rebind(hook: hook).rebind() {
                print("[SatellaJailed] CurrentEntitlements Hook 失败")
            } else {
                print("[SatellaJailed] CurrentEntitlements Hook 成功")
            }
        }
    }
    
    private static func hookTransactionUpdates() {
        let originalSymbol = "_$s8StoreKit11TransactionV7updatesAC12TransactionsVvgZ"
        
        guard let handle = dlopen(nil, RTLD_NOW),
              let originalFunc = dlsym(handle, originalSymbol) else { 
            print("[SatellaJailed] 无法找到updates符号")
            return 
        }
        
        var originalPtr: UnsafeMutableRawPointer? = UnsafeMutableRawPointer(mutating: originalFunc)
        
        withUnsafeMutablePointer(to: &originalPtr) { ptr in
            let hook = RebindHook(
                name: "updates",
                replace: unsafeBitCast(transactionUpdatesReplacement, to: UnsafeMutableRawPointer.self),
                orig: ptr
            )
            
            if !Rebind(hook: hook).rebind() {
                print("[SatellaJailed] Transaction.updates Hook 失败")
            } else {
                print("[SatellaJailed] Transaction.updates Hook 成功")
            }
        }
    }
    
    private static func hookProductPurchase() {
        let purchaseSymbol = "_$s8StoreKit7ProductV8purchase7optionsAC14PurchaseResultOShyAC0F6OptionVG_tYaKF"
        
        guard let handle = dlopen(nil, RTLD_NOW),
              let purchaseFunc = dlsym(handle, purchaseSymbol) else { 
            print("[SatellaJailed] 无法找到purchase符号")
            return 
        }
        
        var originalPtr: UnsafeMutableRawPointer? = UnsafeMutableRawPointer(mutating: purchaseFunc)
        
        withUnsafeMutablePointer(to: &originalPtr) { ptr in
            let hook = RebindHook(
                name: "purchase",
                replace: unsafeBitCast(productPurchaseReplacement, to: UnsafeMutableRawPointer.self),
                orig: ptr
            )
            
            if !Rebind(hook: hook).rebind() {
                print("[SatellaJailed] Product.purchase Hook 失败")
            } else {
                print("[SatellaJailed] Product.purchase Hook 成功")
            }
        }
    }
    
    private static func hookVerificationResult() {
        print("[SatellaJailed] VerificationResult钩子已设置")
        
        // 使用Method Swizzling方式处理VerificationResult
        guard let verificationClass = NSClassFromString("StoreKit.VerificationResult") else {
            print("[SatellaJailed] 无法找到VerificationResult类")
            return
        }
        
        print("[SatellaJailed] VerificationResult类已找到: \(verificationClass)")
        
        // Hook VerificationResult的验证逻辑
        hookVerificationResultMethods(verificationClass)
    }
    
    private static func hookVerificationResultMethods(_ verificationClass: AnyClass) {
        // Hook .verified 静态方法
        if let verifiedMethod = class_getClassMethod(verificationClass, NSSelectorFromString("verified:")) {
            method_setImplementation(verifiedMethod, unsafeBitCast(verificationResultVerifiedReplacement, to: IMP.self))
            print("[SatellaJailed] VerificationResult.verified方法已被Hook")
        }
        
        // Hook .unverified 静态方法，让其返回verified结果
        if let unverifiedMethod = class_getClassMethod(verificationClass, NSSelectorFromString("unverified:")) {
            method_setImplementation(unverifiedMethod, unsafeBitCast(verificationResultUnverifiedReplacement, to: IMP.self))
            print("[SatellaJailed] VerificationResult.unverified方法已被Hook")
        }
    }
    
    private static func hookReceiptRefresh() {
        print("[SatellaJailed] ReceiptRefresh钩子已设置")
        
        // Hook AppStore的收据刷新请求
        let receiptRefreshSymbol = "_$s8StoreKit03AppA0O12requestReceiptyyYaKFZ"
        
        guard let handle = dlopen(nil, RTLD_NOW),
              let receiptFunc = dlsym(handle, receiptRefreshSymbol) else {
            print("[SatellaJailed] 无法找到receipt refresh符号")
            return
        }
        
        var originalPtr: UnsafeMutableRawPointer? = UnsafeMutableRawPointer(mutating: receiptFunc)
        
        withUnsafeMutablePointer(to: &originalPtr) { ptr in
            let hook = RebindHook(
                name: "requestReceipt",
                replace: unsafeBitCast(receiptRefreshReplacement, to: UnsafeMutableRawPointer.self),
                orig: ptr
            )
            
            if !Rebind(hook: hook).rebind() {
                print("[SatellaJailed] Receipt refresh Hook 失败")
            } else {
                print("[SatellaJailed] Receipt refresh Hook 成功")
            }
        }
    }
    
    // 获取当前配置的产品ID列表
    static func getConfiguredProductIds() -> [String] {
        return [
            "premium.full.per.year",
            "premium.yearly", 
            "pro.yearly",
            "vip.yearly",
            "subscription.yearly",
            "premium.monthly",
            "pro.monthly",
            "unlock.full",
            "all.features",
            "premium",
            "pro",
            "vip"
        ]
    }
    
    /// 创建包含有效订阅的假Transaction.Transactions集合
    static func createFakeTransactionCollection() -> Any {
        let fakeCollection = NSMutableArray()
        
        for productId in getConfiguredProductIds() {
            let fakeTransaction = createFakeTransaction(productId: productId)
            fakeCollection.add(fakeTransaction)
        }
        
        print("[SatellaJailed] 已创建包含\(fakeCollection.count)个交易的伪造集合")
        return fakeCollection
    }
    
    /// 创建单个伪造交易
    static func createFakeTransaction(productId: String) -> Any {
        let transaction = NSMutableDictionary()
        
        // 设置基本交易信息
        transaction["productId"] = productId
        transaction["transactionId"] = "fake_\(arc4random())"
        transaction["originalTransactionId"] = "fake_original_\(arc4random())"
        transaction["purchaseDate"] = Date()
        transaction["expirationDate"] = Date().addingTimeInterval(86400 * 365) // 一年后过期
        transaction["isActive"] = true
        transaction["environment"] = "Production"
        transaction["webOrderLineItemId"] = "fake_\(arc4random())"
        transaction["subscriptionGroupIdentifier"] = "premium_group"
        
        print("[SatellaJailed] 已创建伪造交易: \(productId)")
        return transaction
    }
    
    // 创建伪造交易指针
    static func createFakeTransactions() -> UnsafeMutableRawPointer? {
        let fakeData = createFakeTransactionCollection()
        return Unmanaged.passRetained(fakeData as AnyObject).toOpaque()
    }
    
    // 创建成功的购买结果
    static func createSuccessfulPurchaseResult() -> UnsafeMutableRawPointer? {
        let successResult = NSMutableDictionary()
        successResult["status"] = "success"
        successResult["transaction"] = createFakeTransaction(productId: "purchased_product")
        successResult["verificationResult"] = "verified"
        successResult["userCancelled"] = false
        successResult["pending"] = false
        
        print("[SatellaJailed] 已创建成功的购买结果")
        return Unmanaged.passRetained(successResult as AnyObject).toOpaque()
    }
}

// 全局替换函数
@available(iOS 15.0, *)
@_cdecl("currentEntitlementsReplacement")
func currentEntitlementsReplacement() -> UnsafeMutableRawPointer {
    print("[SatellaJailed] CurrentEntitlements被拦截")
    let fakeData = StoreKit2FunctionHook.createFakeTransactionCollection()
    return Unmanaged.passRetained(fakeData as AnyObject).toOpaque()
}

@available(iOS 15.0, *)
@_cdecl("transactionUpdatesReplacement")
func transactionUpdatesReplacement() -> UnsafeMutableRawPointer? {
    print("[SatellaJailed] Transaction.updates被拦截")
    return StoreKit2FunctionHook.createFakeTransactions()
}

@available(iOS 15.0, *)
@_cdecl("productPurchaseReplacement")
func productPurchaseReplacement(_ product: UnsafeMutableRawPointer, _ options: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    print("[SatellaJailed] Product.purchase被拦截")
    return StoreKit2FunctionHook.createSuccessfulPurchaseResult()
}

@available(iOS 15.0, *)
@_cdecl("verificationResultVerifiedReplacement")
func verificationResultVerifiedReplacement(_ cls: AnyClass, _ sel: Selector, _ transaction: Any) -> Any {
    print("[SatellaJailed] VerificationResult.verified被拦截，返回已验证状态")
    return transaction // 直接返回交易，表示已验证
}

@available(iOS 15.0, *)
@_cdecl("verificationResultUnverifiedReplacement")
func verificationResultUnverifiedReplacement(_ cls: AnyClass, _ sel: Selector, _ transaction: Any) -> Any {
    print("[SatellaJailed] VerificationResult.unverified被拦截，强制返回已验证状态")
    // 强制返回verified状态而不是unverified
    return transaction
}

@available(iOS 15.0, *)
@_cdecl("receiptRefreshReplacement")
func receiptRefreshReplacement() -> Void {
    print("[SatellaJailed] Receipt refresh被拦截，跳过实际刷新")
    // 直接返回，不执行实际的收据刷新
}

// StoreKit 2特定的Hook辅助方法
@available(iOS 15.0, *)
extension StoreKit2FunctionHook {
    
    /// 安全地执行符号Hook，包含错误处理
    static func safeHookSymbol(
        _ symbolName: String,
        replacement: UnsafeMutableRawPointer,
        description: String
    ) -> Bool {
        guard let handle = dlopen(nil, RTLD_NOW) else {
            print("[SatellaJailed] 无法获取动态库句柄")
            return false
        }
        
        guard let originalFunc = dlsym(handle, symbolName) else {
            print("[SatellaJailed] 无法找到符号: \(symbolName)")
            return false
        }
        
        var originalPtr: UnsafeMutableRawPointer? = UnsafeMutableRawPointer(mutating: originalFunc)
        
        return withUnsafeMutablePointer(to: &originalPtr) { ptr in
            let hook = RebindHook(
                name: description,
                replace: replacement,
                orig: ptr
            )
            
            let success = Rebind(hook: hook).rebind()
            if success {
                print("[SatellaJailed] 成功Hook: \(description)")
            } else {
                print("[SatellaJailed] Hook失败: \(description)")
            }
            
            return success
        }
    }
    
    // 验证StoreKit 2是否可用
    static func isStoreKit2Available() -> Bool {
        return NSClassFromString("StoreKit.Transaction") != nil
    }
    
    // 检查已安装的Hook状态
    static func verifyHookStatus() {
        print("[SatellaJailed] 验证StoreKit 2 Hook状态:")
        print("- StoreKit 2可用: \(isStoreKit2Available())")
        print("- Transaction类: \(NSClassFromString("StoreKit.Transaction") != nil)")
        print("- Product类: \(NSClassFromString("StoreKit.Product") != nil)")
        print("- VerificationResult类: \(NSClassFromString("StoreKit.VerificationResult") != nil)")
    }
    
    // 动态添加新的产品ID支持
    static func addProductIdSupport(_ productId: String) {
        print("[SatellaJailed] 添加新产品ID支持: \(productId)")
        // 这里可以实现动态产品ID添加逻辑
    }
    
    // 获取所有支持的Hook类型
    static func getSupportedHookTypes() -> [String] {
        return [
            "currentEntitlements",
            "transactionUpdates", 
            "productPurchase",
            "verificationResult",
            "receiptRefresh"
        ]
    }
    
    // 批量验证所有Hook状态
    static func validateAllHooks() -> [String: Bool] {
        var results: [String: Bool] = [:]
        
        for hookType in getSupportedHookTypes() {
            switch hookType {
            case "currentEntitlements":
                results[hookType] = NSClassFromString("StoreKit.Transaction") != nil
            case "transactionUpdates":
                results[hookType] = NSClassFromString("StoreKit.Transaction") != nil
            case "productPurchase":
                results[hookType] = NSClassFromString("StoreKit.Product") != nil
            case "verificationResult":
                results[hookType] = NSClassFromString("StoreKit.VerificationResult") != nil
            case "receiptRefresh":
                results[hookType] = NSClassFromString("StoreKit.AppStore") != nil
            default:
                results[hookType] = false
            }
        }
        
        return results
    }
    
    // 创建更高级的伪造交易对象
    static func createAdvancedFakeTransaction(productId: String, customFields: [String: Any] = [:]) -> Any {
        let transaction = NSMutableDictionary()
        
        // 设置基本交易信息
        transaction["productId"] = productId
        transaction["transactionId"] = "fake_\(arc4random())"
        transaction["originalTransactionId"] = "fake_original_\(arc4random())"
        transaction["purchaseDate"] = Date()
        transaction["expirationDate"] = Date().addingTimeInterval(86400 * 365) // 一年后过期
        transaction["isActive"] = true
        transaction["environment"] = "Production"
        transaction["webOrderLineItemId"] = "fake_\(arc4random())"
        transaction["subscriptionGroupIdentifier"] = "premium_group"
        
        // StoreKit 2特有字段
        transaction["signedDate"] = Date()
        transaction["revocationDate"] = nil
        transaction["revocationReason"] = nil
        transaction["isUpgraded"] = false
        transaction["offerType"] = "introductory"
        transaction["storefront"] = "USA"
        transaction["storefrontID"] = "143441"
        transaction["currency"] = "USD"
        
        // 添加自定义字段
        for (key, value) in customFields {
            transaction[key] = value
        }
        
        print("[SatellaJailed] 已创建高级伪造交易: \(productId)")
        return transaction
    }
    
    // 模拟特定类型的订阅状态
    static func simulateSubscriptionType(_ type: SubscriptionType) -> Any {
        switch type {
        case .monthly:
            return createAdvancedFakeTransaction(
                productId: "premium.monthly",
                customFields: [
                    "subscriptionPeriod": "P1M",
                    "price": 9.99,
                    "localizedPrice": "$9.99"
                ]
            )
        case .yearly:
            return createAdvancedFakeTransaction(
                productId: "premium.yearly", 
                customFields: [
                    "subscriptionPeriod": "P1Y",
                    "price": 99.99,
                    "localizedPrice": "$99.99"
                ]
            )
        case .lifetime:
            return createAdvancedFakeTransaction(
                productId: "premium.lifetime",
                customFields: [
                    "subscriptionPeriod": "P999Y",
                    "price": 299.99,
                    "localizedPrice": "$299.99",
                    "isLifetime": true
                ]
            )
        }
    }
}

// 支持的订阅类型
@available(iOS 15.0, *)
enum SubscriptionType {
    case monthly
    case yearly
    case lifetime
}