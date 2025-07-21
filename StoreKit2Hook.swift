import Foundation
import StoreKit
import MachO

@available(iOS 15.0, *)
class StoreKit2UniversalHook: Hook {
    typealias T = @convention(c) () -> Void
    var cls: AnyClass? { return nil }
    var sel: Selector { return #selector(NSObject.description) }
    var replace: T { return {} }

    static var shared: StoreKit2UniversalHook?
    
    // C 函数指针
    private let fakeCurrentEntitlements: @convention(c) () -> UnsafeMutableRawPointer = {
        print("[StoreKit2] C Hook - currentEntitlements")
        let fakeEntitlements = NSArray(array: [
            ["productID": "premium.yearly", "expirationDate": Date().addingTimeInterval(365*24*3600)],
            ["productID": "premium.monthly", "expirationDate": Date().addingTimeInterval(30*24*3600)],
            ["productID": "premium.weekly", "expirationDate": Date().addingTimeInterval(7*24*3600)]
        ])
        return unsafeBitCast(fakeEntitlements, to: UnsafeMutableRawPointer.self)
    }
    
    private let fakeVerificationResult: @convention(c) () -> UnsafeMutableRawPointer = {
        print("[StoreKit2] C Hook - verificationResult")
        let result = NSMutableDictionary()
        result["verified"] = true
        result["payloadData"] = Data()
        return unsafeBitCast(result, to: UnsafeMutableRawPointer.self)
    }
    
    private let fakePurchase: @convention(c) () -> UnsafeMutableRawPointer = {
        print("[StoreKit2] C Hook - purchase")
        let result = NSMutableDictionary()
        result["transaction"] = [
            "id": "fake_transaction_\(UUID().uuidString)",
            "productID": "premium.subscription",
            "purchaseDate": Date(),
            "state": 1
        ]
        result["userCancelled"] = false
        return unsafeBitCast(result, to: UnsafeMutableRawPointer.self)
    }
    
    private let fakeSubscriptionStatus: @convention(c) () -> UnsafeMutableRawPointer = {
        print("[StoreKit2] C Hook - subscriptionStatus")
        let status = NSMutableDictionary()
        status["state"] = 1
        status["renewalInfo"] = [
            "willAutoRenew": true,
            "expirationDate": Date().addingTimeInterval(365*24*3600),
            "autoRenewProductID": "premium.subscription"
        ]
        return unsafeBitCast(status, to: UnsafeMutableRawPointer.self)
    }
    
    private let fakeDefault: @convention(c) () -> UnsafeMutableRawPointer = {
        print("[StoreKit2] C Hook - default")
        return unsafeBitCast(NSNumber(value: true), to: UnsafeMutableRawPointer.self)
    }
    
    private let fakeSQLiteExec: @convention(c) (OpaquePointer?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32 = { db, sql, callback, callbackArg, errmsg in
        if let sqlString = sql {
            let query = String(cString: sqlString)
            print("[StoreKit2] SQLite exec: \(query)")
            
            if query.lowercased().contains("transaction") || query.lowercased().contains("purchase") || 
               query.lowercased().contains("subscription") || query.lowercased().contains("receipt") {
                print("[StoreKit2] Intercepted StoreKit SQLite query")
                return 0
            }
        }
        return 0
    }
    
    private let fakeSQLiteStep: @convention(c) (OpaquePointer?) -> Int32 = { stmt in
        print("[StoreKit2] SQLite step intercepted")
        return 101
    }
    
    private let fakeSQLitePrepare: @convention(c) (OpaquePointer?, UnsafePointer<CChar>?, Int32, UnsafeMutablePointer<OpaquePointer?>?, UnsafeMutablePointer<UnsafePointer<CChar>?>?) -> Int32 = { db, sql, nByte, ppStmt, pzTail in
        if let sqlString = sql {
            let query = String(cString: sqlString)
            print("[StoreKit2] SQLite prepare: \(query)")
        }
        return 0
    }
    
    private let fakeOpen: @convention(c) (UnsafePointer<CChar>?, Int32, Int32) -> Int32 = { path, flags, mode in
        if let pathString = path {
            let pathStr = String(cString: pathString)
            print("[StoreKit2] File open: \(pathStr)")
            
            if pathStr.contains("StoreKit") || pathStr.contains("transaction") || 
               pathStr.contains("receipt") || pathStr.contains("purchase") {
                print("[StoreKit2] Intercepted StoreKit file access")
                return -1
            }
        }
        return 0
    }
    
    private let fakeFOpen: @convention(c) (UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> UnsafeMutablePointer<FILE>? = { filename, mode in
        if let filenameString = filename {
            let filenameStr = String(cString: filenameString)
            print("[StoreKit2] File fopen: \(filenameStr)")
            
            if filenameStr.contains("StoreKit") || filenameStr.contains("transaction") ||
               filenameStr.contains("receipt") || filenameStr.contains("purchase") {
                print("[StoreKit2] Intercepted StoreKit file fopen")
                return nil
            }
        }
        return nil
    }
    
    private let fakeRead: @convention(c) (Int32, UnsafeMutableRawPointer?, Int) -> Int = { fd, buf, count in
        print("[StoreKit2] File read intercepted: fd=\(fd), count=\(count)")
        return 0
    }
    
    private let fakeFRead: @convention(c) (UnsafeMutableRawPointer?, Int, Int, UnsafeMutablePointer<FILE>?) -> Int = { ptr, size, nmemb, stream in
        print("[StoreKit2] File fread intercepted: size=\(size), nmemb=\(nmemb)")
        return 0
    }
    
    func hook() {
        StoreKit2UniversalHook.shared = self
        
        hookTransactionVerification()
        hookProductPurchase()
        hookSubscriptionStatus()
        hookSQLiteOperations()
        hookNetworkValidation()
        hookRuntimeMethods()
        hookSwiftRuntimeClasses()
    }
    
    private func hookTransactionVerification() {
        hookSwiftMethod(moduleName: "StoreKit", className: "Transaction", methodName: "currentEntitlements")
        hookSwiftMethod(moduleName: "StoreKit", className: "Transaction", methodName: "verificationResult")
        hookSwiftMethod(moduleName: "StoreKit", className: "VerificationResult", methodName: "get")
        
        if let transactionClass = objc_getClass("StoreKit.Transaction") as? AnyClass {
            hookObjCMethod(class: transactionClass, selector: "currentEntitlements", implementation: fakeCurrentEntitlementsObjC)
            hookObjCMethod(class: transactionClass, selector: "verificationResult", implementation: fakeVerificationResultObjC)
        }
    }
    
    private func hookProductPurchase() {
        hookSwiftMethod(moduleName: "StoreKit", className: "Product", methodName: "purchase")
        hookSwiftMethod(moduleName: "StoreKit", className: "Product", methodName: "subscription")
        
        if let productClass = objc_getClass("StoreKit.Product") as? AnyClass {
            hookObjCMethod(class: productClass, selector: "purchase", implementation: fakePurchaseObjC)
            hookObjCMethod(class: productClass, selector: "subscription", implementation: fakeSubscriptionObjC)
        }
    }
    
    private func hookSubscriptionStatus() {
        hookSwiftMethod(moduleName: "StoreKit", className: "SubscriptionInfo", methodName: "status")
        hookSwiftMethod(moduleName: "StoreKit", className: "RenewalInfo", methodName: "willAutoRenew")
        
        if let subscriptionClass = objc_getClass("StoreKit.Product.SubscriptionInfo") as? AnyClass {
            hookObjCMethod(class: subscriptionClass, selector: "status", implementation: fakeSubscriptionStatusObjC)
        }
        
        if let renewalClass = objc_getClass("StoreKit.Product.SubscriptionInfo.RenewalInfo") as? AnyClass {
            hookObjCMethod(class: renewalClass, selector: "willAutoRenew", implementation: fakeWillAutoRenewObjC)
        }
    }
    
    private func hookSwiftRuntimeClasses() {
        let swiftClassNames = [
            "_TtC8StoreKit11Transaction",
            "_TtC8StoreKit7Product", 
            "_TtC8StoreKit18VerificationResult",
            "_TtC8StoreKit16SubscriptionInfo",
            "_TtC8StoreKit11RenewalInfo"
        ]
        
        for className in swiftClassNames {
            if let swiftClass = objc_getClass(className) as? AnyClass {
                let methodCount = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
                if let methods = class_copyMethodList(swiftClass, methodCount) {
                    for i in 0..<Int(methodCount.pointee) {
                        let method = methods[i]
                        let selector = method_getName(method)
                        let selectorName = NSStringFromSelector(selector)
                        
                        if selectorName.contains("entitlements") || selectorName.contains("verification") || 
                           selectorName.contains("purchase") || selectorName.contains("subscription") ||
                           selectorName.contains("status") || selectorName.contains("renew") {
                            
                            let newImpl = createFakeImplementation(for: selectorName)
                            method_setImplementation(method, newImpl)
                            
                            print("[StoreKit2] Hooked Swift method: \(className).\(selectorName)")
                        }
                    }
                    free(methods)
                }
                methodCount.deallocate()
            }
        }
    }
    
    private func createFakeImplementation(for selectorName: String) -> IMP {
        if selectorName.contains("entitlements") {
            return imp_implementationWithBlock({ () -> Any in
                print("[StoreKit2] Fake entitlements called")
                return self.createFakeEntitlements()
            })
        } else if selectorName.contains("verification") {
            return imp_implementationWithBlock({ () -> Any in
                print("[StoreKit2] Fake verification called")
                return self.createFakeVerificationResult()
            })
        } else if selectorName.contains("purchase") {
            return imp_implementationWithBlock({ () -> Any in
                print("[StoreKit2] Fake purchase called")
                return self.createFakePurchaseResult()
            })
        } else if selectorName.contains("subscription") {
            return imp_implementationWithBlock({ () -> Any in
                print("[StoreKit2] Fake subscription called")
                return self.createFakeSubscriptionInfo()
            })
        } else if selectorName.contains("status") {
            return imp_implementationWithBlock({ () -> Any in
                print("[StoreKit2] Fake status called")
                return self.createFakeSubscriptionStatus()
            })
        } else if selectorName.contains("renew") {
            return imp_implementationWithBlock({ () -> Bool in
                print("[StoreKit2] Fake auto renew called")
                return true
            })
        }
        
        return imp_implementationWithBlock({ () -> Any in
            print("[StoreKit2] Default fake implementation called")
            return NSNumber(value: true)
        })
    }
    
    private func hookSwiftMethod(moduleName: String, className: String, methodName: String) {
        let symbols = [
            "_$s\(moduleName.count)\(moduleName)\(className.count)\(className)\(methodName.count)\(methodName)",
            "$s\(moduleName.count)\(moduleName)\(className.count)\(className)\(methodName.count)\(methodName)",
            "\(moduleName).\(className).\(methodName)"
        ]
        
        for symbol in symbols {
            if let address = dlsym(dlopen(nil, RTLD_NOW), symbol) {
                print("[StoreKit2] Found symbol: \(symbol)")
                hookFunctionAtAddress(address: address, symbol: symbol)
                break
            }
        }
    }
    
    private func hookFunctionAtAddress(address: UnsafeMutableRawPointer, symbol: String) {
        let pageSize = Int(getpagesize())
        let alignedAddress = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: address) & ~UInt(pageSize - 1))
        
        if let alignedAddr = alignedAddress, mprotect(alignedAddr, pageSize, PROT_READ | PROT_WRITE | PROT_EXEC) == 0 {
            createJumpInstruction(at: address, to: getFakeImplementation(for: symbol))
            mprotect(alignedAddr, pageSize, PROT_READ | PROT_EXEC)
            print("[StoreKit2] Successfully hooked symbol: \(symbol)")
        }
    }
    
    private func getFakeImplementation(for symbol: String) -> UnsafeMutableRawPointer {
        if symbol.contains("currentEntitlements") {
            return unsafeBitCast(fakeCurrentEntitlements, to: UnsafeMutableRawPointer.self)
        } else if symbol.contains("verificationResult") {
            return unsafeBitCast(fakeVerificationResult, to: UnsafeMutableRawPointer.self)
        } else if symbol.contains("purchase") {
            return unsafeBitCast(fakePurchase, to: UnsafeMutableRawPointer.self)
        } else if symbol.contains("status") {
            return unsafeBitCast(fakeSubscriptionStatus, to: UnsafeMutableRawPointer.self)
        }
        
        return unsafeBitCast(fakeDefault, to: UnsafeMutableRawPointer.self)
    }
    
    private func createJumpInstruction(at address: UnsafeMutableRawPointer, to target: UnsafeMutableRawPointer) {
        #if arch(arm64)
        let offset = Int64(Int(bitPattern: target)) - Int64(Int(bitPattern: address))
        let instruction: UInt32 = 0x14000000 | UInt32((offset >> 2) & 0x3FFFFFF)
        address.assumingMemoryBound(to: UInt32.self).pointee = instruction
        #elseif arch(x86_64)
        address.assumingMemoryBound(to: UInt8.self).pointee = 0xE9
        let offset = Int32(Int(bitPattern: target)) - Int32(Int(bitPattern: address)) - 5
        (address + 1).assumingMemoryBound(to: Int32.self).pointee = offset
        #endif
    }
    
    private func hookSQLiteOperations() {
        let sqliteFunctions = ["sqlite3_exec", "sqlite3_prepare_v2", "sqlite3_step", "sqlite3_column_text"]
        
        for funcName in sqliteFunctions {
            if let original = dlsym(dlopen(nil, RTLD_NOW), funcName) {
                print("[StoreKit2] Found SQLite function: \(funcName)")
                hookSQLiteFunction(name: funcName, original: original)
            }
        }
        
        hookFileOperations()
    }
    
    private func hookSQLiteFunction(name: String, original: UnsafeMutableRawPointer) {
        switch name {
        case "sqlite3_exec":
            swapSQLiteExecFunction(original: original)
        case "sqlite3_step":
            swapSQLiteStepFunction(original: original)
        case "sqlite3_prepare_v2":
            swapSQLitePrepareFunction(original: original)
        default:
            break
        }
    }
    
    private func swapSQLiteExecFunction(original: UnsafeMutableRawPointer) {
        let pageSize = Int(getpagesize())
        let alignedAddress = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: original) & ~UInt(pageSize - 1))
        
        if let alignedAddr = alignedAddress, mprotect(alignedAddr, pageSize, PROT_READ | PROT_WRITE | PROT_EXEC) == 0 {
            let fakeFunc = unsafeBitCast(fakeSQLiteExec, to: UnsafeMutableRawPointer.self)
            createJumpInstruction(at: original, to: fakeFunc)
            mprotect(alignedAddr, pageSize, PROT_READ | PROT_EXEC)
            print("[StoreKit2] Hooked sqlite3_exec")
        }
    }
    
    private func swapSQLiteStepFunction(original: UnsafeMutableRawPointer) {
        let pageSize = Int(getpagesize())
        let alignedAddress = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: original) & ~UInt(pageSize - 1))
        
        if let alignedAddr = alignedAddress, mprotect(alignedAddr, pageSize, PROT_READ | PROT_WRITE | PROT_EXEC) == 0 {
            let fakeFunc = unsafeBitCast(fakeSQLiteStep, to: UnsafeMutableRawPointer.self)
            createJumpInstruction(at: original, to: fakeFunc)
            mprotect(alignedAddr, pageSize, PROT_READ | PROT_EXEC)
            print("[StoreKit2] Hooked sqlite3_step")
        }
    }
    
    private func swapSQLitePrepareFunction(original: UnsafeMutableRawPointer) {
        let pageSize = Int(getpagesize())
        let alignedAddress = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: original) & ~UInt(pageSize - 1))
        
        if let alignedAddr = alignedAddress, mprotect(alignedAddr, pageSize, PROT_READ | PROT_WRITE | PROT_EXEC) == 0 {
            let fakeFunc = unsafeBitCast(fakeSQLitePrepare, to: UnsafeMutableRawPointer.self)
            createJumpInstruction(at: original, to: fakeFunc)
            mprotect(alignedAddr, pageSize, PROT_READ | PROT_EXEC)
            print("[StoreKit2] Hooked sqlite3_prepare_v2")
        }
    }
    
    private func hookFileOperations() {
        let fileSystemFunctions = ["open", "read", "write", "fopen", "fread", "fwrite"]
        
        for funcName in fileSystemFunctions {
            if let original = dlsym(dlopen(nil, RTLD_NOW), funcName) {
                print("[StoreKit2] Found file system function: \(funcName)")
                hookFileSystemFunction(name: funcName, original: original)
            }
        }
    }
    
    private func hookFileSystemFunction(name: String, original: UnsafeMutableRawPointer) {
        switch name {
        case "open":
            swapOpenFunction(original: original)
        case "fopen":
            swapFOpenFunction(original: original)
        case "read":
            swapReadFunction(original: original)
        case "fread":
            swapFReadFunction(original: original)
        default:
            break
        }
    }
    
    private func swapOpenFunction(original: UnsafeMutableRawPointer) {
        let pageSize = Int(getpagesize())
        let alignedAddress = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: original) & ~UInt(pageSize - 1))
        
        if let alignedAddr = alignedAddress, mprotect(alignedAddr, pageSize, PROT_READ | PROT_WRITE | PROT_EXEC) == 0 {
            let fakeFunc = unsafeBitCast(fakeOpen, to: UnsafeMutableRawPointer.self)
            createJumpInstruction(at: original, to: fakeFunc)
            mprotect(alignedAddr, pageSize, PROT_READ | PROT_EXEC)
            print("[StoreKit2] Hooked open")
        }
    }
    
    private func swapFOpenFunction(original: UnsafeMutableRawPointer) {
        let pageSize = Int(getpagesize())
        let alignedAddress = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: original) & ~UInt(pageSize - 1))
        
        if let alignedAddr = alignedAddress, mprotect(alignedAddr, pageSize, PROT_READ | PROT_WRITE | PROT_EXEC) == 0 {
            let fakeFunc = unsafeBitCast(fakeFOpen, to: UnsafeMutableRawPointer.self)
            createJumpInstruction(at: original, to: fakeFunc)
            mprotect(alignedAddr, pageSize, PROT_READ | PROT_EXEC)
            print("[StoreKit2] Hooked fopen")
        }
    }
    
    private func swapReadFunction(original: UnsafeMutableRawPointer) {
        let pageSize = Int(getpagesize())
        let alignedAddress = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: original) & ~UInt(pageSize - 1))
        
        if let alignedAddr = alignedAddress, mprotect(alignedAddr, pageSize, PROT_READ | PROT_WRITE | PROT_EXEC) == 0 {
            let fakeFunc = unsafeBitCast(fakeRead, to: UnsafeMutableRawPointer.self)
            createJumpInstruction(at: original, to: fakeFunc)
            mprotect(alignedAddr, pageSize, PROT_READ | PROT_EXEC)
            print("[StoreKit2] Hooked read")
        }
    }
    
    private func swapFReadFunction(original: UnsafeMutableRawPointer) {
        let pageSize = Int(getpagesize())
        let alignedAddress = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: original) & ~UInt(pageSize - 1))
        
        if let alignedAddr = alignedAddress, mprotect(alignedAddr, pageSize, PROT_READ | PROT_WRITE | PROT_EXEC) == 0 {
            let fakeFunc = unsafeBitCast(fakeFRead, to: UnsafeMutableRawPointer.self)
            createJumpInstruction(at: original, to: fakeFunc)
            mprotect(alignedAddr, pageSize, PROT_READ | PROT_EXEC)
            print("[StoreKit2] Hooked fread")
        }
    }
    
    private func hookNetworkValidation() {
        if let urlConnectionClass = NSClassFromString("NSURLConnection") {
            hookObjCMethod(
                class: urlConnectionClass,
                selector: "sendAsynchronousRequest:queue:completionHandler:",
                implementation: fakeURLConnection
            )
        }
        
        if let urlSessionClass = NSClassFromString("NSURLSession") {
            hookObjCMethod(
                class: urlSessionClass,
                selector: "dataTaskWithRequest:completionHandler:",
                implementation: fakeURLSessionDataTask
            )
        }
        
        if let cfNetworkClass = NSClassFromString("__NSCFURLSessionDataTask") {
            hookObjCMethod(
                class: cfNetworkClass,
                selector: "resume",
                implementation: fakeURLTaskResume
            )
        }
    }
    
    private func hookRuntimeMethods() {
        if let userDefaultsClass = NSClassFromString("NSUserDefaults") {
            hookObjCMethod(
                class: userDefaultsClass,
                selector: "objectForKey:",
                implementation: fakeUserDefaultsObjectForKey
            )
            
            hookObjCMethod(
                class: userDefaultsClass,
                selector: "boolForKey:",
                implementation: fakeUserDefaultsBoolForKey
            )
            
            hookObjCMethod(
                class: userDefaultsClass,
                selector: "dataForKey:",
                implementation: fakeUserDefaultsDataForKey
            )
        }
        
        if let unarchiverClass = NSClassFromString("NSKeyedUnarchiver") {
            hookObjCMethod(
                class: unarchiverClass,
                selector: "unarchiveObjectWithData:",
                implementation: fakeUnarchiveObjectWithData
            )
            
            hookObjCMethod(
                class: unarchiverClass,
                selector: "unarchivedObjectOfClass:fromData:error:",
                implementation: fakeUnarchivedObjectOfClass
            )
        }
        
        if let keychainClass = NSClassFromString("SecItem") {
            hookObjCMethod(
                class: keychainClass,
                selector: "copyMatching:",
                implementation: fakeKeychainCopyMatching
            )
        }
    }
    
    private func hookObjCMethod(class: AnyClass, selector: String, implementation: Any) {
        let selectorObj = NSSelectorFromString(selector)
        if let method = class_getInstanceMethod(`class`, selectorObj) {
            let newIMP = imp_implementationWithBlock(implementation)
            method_setImplementation(method, newIMP)
            print("[StoreKit2] Successfully hooked \(`class`).\(selector)")
        }
    }
}

// MARK: - Objective-C 方法实现
@available(iOS 15.0, *)
extension StoreKit2UniversalHook {
    private func fakeCurrentEntitlementsObjC() -> Any {
        print("[StoreKit2] ObjC Hook - currentEntitlements")
        return createFakeEntitlements()
    }
    
    private func fakeVerificationResultObjC() -> Any {
        print("[StoreKit2] ObjC Hook - verificationResult")
        return createFakeVerificationResult()
    }
    
    private func fakePurchaseObjC() -> Any {
        print("[StoreKit2] ObjC Hook - purchase")
        return createFakePurchaseResult()
    }
    
    private func fakeSubscriptionObjC() -> Any {
        print("[StoreKit2] ObjC Hook - subscription")
        return createFakeSubscriptionInfo()
    }
    
    private func fakeSubscriptionStatusObjC() -> Any {
        print("[StoreKit2] ObjC Hook - subscriptionStatus")
        return createFakeSubscriptionStatus()
    }
    
    private func fakeWillAutoRenewObjC() -> Bool {
        print("[StoreKit2] ObjC Hook - willAutoRenew")
        return true
    }
    
    private func fakeURLConnection() -> Any {
        print("[StoreKit2] Intercepted NSURLConnection request")
        return createFakeNetworkResponse()
    }
    
    private func fakeURLSessionDataTask() -> Any {
        print("[StoreKit2] Intercepted NSURLSession request")
        return createFakeNetworkResponse()
    }
    
    private func fakeURLTaskResume() -> Void {
        print("[StoreKit2] Intercepted URLTask resume")
    }
    
    private func fakeUserDefaultsObjectForKey() -> Any? {
        print("[StoreKit2] Intercepted NSUserDefaults objectForKey")
        return createFakeUserDefaultsValue()
    }
    
    private func fakeUserDefaultsBoolForKey() -> Bool {
        print("[StoreKit2] Intercepted NSUserDefaults boolForKey")
        return true
    }
    
    private func fakeUserDefaultsDataForKey() -> Data? {
        print("[StoreKit2] Intercepted NSUserDefaults dataForKey")
        return createFakeReceiptData()
    }
    
    private func fakeUnarchiveObjectWithData() -> Any? {
        print("[StoreKit2] Intercepted NSKeyedUnarchiver unarchiveObjectWithData")
        return createFakeArchivedObject()
    }
    
    private func fakeUnarchivedObjectOfClass() -> Any? {
        print("[StoreKit2] Intercepted NSKeyedUnarchiver unarchivedObjectOfClass")
        return createFakeArchivedObject()
    }
    
    private func fakeKeychainCopyMatching() -> OSStatus {
        print("[StoreKit2] Intercepted Keychain access")
        return noErr
    }
    
    private func createFakeEntitlements() -> [String: Any] {
        return [
            "currentEntitlements": [
                [
                    "productID": "premium.yearly",
                    "expirationDate": Date().addingTimeInterval(365*24*3600),
                    "transactionID": "fake_transaction_yearly_\(UUID().uuidString)",
                    "originalTransactionID": "fake_original_yearly_\(UUID().uuidString)",
                    "subscriptionGroupID": "premium_group",
                    "webOrderLineItemID": "fake_web_\(UUID().uuidString)"
                ],
                [
                    "productID": "premium.monthly", 
                    "expirationDate": Date().addingTimeInterval(30*24*3600),
                    "transactionID": "fake_transaction_monthly_\(UUID().uuidString)",
                    "originalTransactionID": "fake_original_monthly_\(UUID().uuidString)",
                    "subscriptionGroupID": "premium_group",
                    "webOrderLineItemID": "fake_web_\(UUID().uuidString)"
                ]
            ]
        ]
    }
    
    private func createFakeVerificationResult() -> [String: Any] {
        return [
            "verified": true,
            "signedType": "Transaction",
            "payloadData": Data(),
            "signature": "fake_signature_\(UUID().uuidString)",
            "certificateChain": ["fake_cert_1", "fake_cert_2"]
        ]
    }
    
    private func createFakePurchaseResult() -> [String: Any] {
        return [
            "transaction": [
                "id": "fake_transaction_\(UUID().uuidString)",
                "productID": "premium.subscription",
                "purchaseDate": Date(),
                "expirationDate": Date().addingTimeInterval(365*24*3600),
                "state": 1,
                "reason": 0,
                "storefront": "USA",
                "storefrontID": "143441",
                "deviceVerification": "fake_device_verification",
                "deviceVerificationNonce": UUID()
            ],
            "userCancelled": false,
            "pending": false
        ]
    }
    
    private func createFakeSubscriptionInfo() -> [String: Any] {
        return [
            "subscriptionGroupID": "premium_group",
            "subscriptionPeriod": [
                "value": 1,
                "unit": "year"
            ],
            "introductoryOffer": [
                "paymentMode": "freeTrial",
                "price": 0.0,
                "period": [
                    "value": 7,
                    "unit": "day"
                ]
            ],
            "promotionalOffers": [],
            "status": [
                "state": 1,
                "renewalInfo": createFakeRenewalInfo()
            ]
        ]
    }
    
    private func createFakeSubscriptionStatus() -> [String: Any] {
        return [
            "state": 1,
            "renewalInfo": createFakeRenewalInfo(),
            "transaction": [
                "id": "fake_status_transaction_\(UUID().uuidString)",
                "productID": "premium.subscription",
                "subscriptionGroupID": "premium_group",
                "purchaseDate": Date(),
                "expirationDate": Date().addingTimeInterval(365*24*3600)
            ]
        ]
    }
    
    private func createFakeRenewalInfo() -> [String: Any] {
        return [
            "willAutoRenew": true,
            "autoRenewProductID": "premium.subscription",
            "expirationDate": Date().addingTimeInterval(365*24*3600),
            "gracePeriodExpirationDate": NSNull(),
            "isInBillingRetryPeriod": false,
            "offerIdentifier": NSNull(),
            "offerType": 0,
            "priceIncreaseStatus": 0,
            "renewalDate": Date().addingTimeInterval(365*24*3600),
            "signedDate": Date(),
            "subscriptionGroupID": "premium_group"
        ]
    }
    
    private func createFakeNetworkResponse() -> Data {
        let response: [String: Any] = [
            "status": 0,
            "environment": "Production", 
            "receipt": [
                "receipt_type": "Production",
                "bundle_id": Bundle.main.bundleIdentifier ?? "com.example.app",
                "application_version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "1.0",
                "download_id": 123456789,
                "version_external_identifier": 987654321,
                "receipt_creation_date": "2024-01-01 00:00:00 Etc/GMT",
                "receipt_creation_date_ms": "1704067200000",
                "receipt_creation_date_pst": "2024-01-01 00:00:00 America/Los_Angeles",
                "request_date": "2024-07-21 00:00:00 Etc/GMT",
                "request_date_ms": "1721520000000",
                "request_date_pst": "2024-07-21 00:00:00 America/Los_Angeles",
                "original_purchase_date": "2024-01-01 00:00:00 Etc/GMT",
                "original_purchase_date_ms": "1704067200000",
                "original_purchase_date_pst": "2024-01-01 00:00:00 America/Los_Angeles",
                "original_application_version": "1.0",
                "in_app": [
                    [
                        "quantity": "1",
                        "product_id": "premium.yearly",
                        "transaction_id": "fake_transaction_yearly_\(UUID().uuidString)",
                        "original_transaction_id": "fake_original_yearly_\(UUID().uuidString)",
                        "purchase_date": "2024-01-01 00:00:00 Etc/GMT",
                        "purchase_date_ms": "1704067200000",
                        "purchase_date_pst": "2024-01-01 00:00:00 America/Los_Angeles",
                        "original_purchase_date": "2024-01-01 00:00:00 Etc/GMT",
                        "original_purchase_date_ms": "1704067200000",
                        "original_purchase_date_pst": "2024-01-01 00:00:00 America/Los_Angeles",
                        "expires_date": "2025-01-01 00:00:00 Etc/GMT",
                        "expires_date_ms": "1735689600000",
                        "expires_date_pst": "2025-01-01 00:00:00 America/Los_Angeles",
                        "web_order_line_item_id": "fake_web_\(UUID().uuidString)",
                        "is_trial_period": "false",
                        "is_in_intro_offer_period": "false",
                        "subscription_group_identifier": "premium_group"
                    ]
                ]
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: response)
    }
    
    private func createFakeReceiptData() -> Data {
        let receiptDict: [String: Any] = [
            "productIdentifier": "premium.subscription",
            "transactionIdentifier": "fake_receipt_\(UUID().uuidString)",
            "transactionDate": Date(),
            "expirationDate": Date().addingTimeInterval(365*24*3600),
            "subscriptionExpirationDate": Date().addingTimeInterval(365*24*3600),
            "cancellationDate": NSNull(),
            "webOrderLineItemID": "fake_receipt_web_\(UUID().uuidString)",
            "subscriptionGroupIdentifier": "premium_group"
        ]
        return try! JSONSerialization.data(withJSONObject: receiptDict)
    }
    
    private func createFakeUserDefaultsValue() -> Any {
        let fakeData = NSMutableDictionary()
        fakeData["isPremium"] = true
        fakeData["subscriptionActive"] = true
        fakeData["subscriptionType"] = "yearly"
        fakeData["purchaseDate"] = Date()
        fakeData["expirationDate"] = Date().addingTimeInterval(365*24*3600)
        fakeData["transactionID"] = "fake_userdefaults_\(UUID().uuidString)"
        fakeData["originalTransactionID"] = "fake_userdefaults_original_\(UUID().uuidString)"
        fakeData["productIdentifier"] = "premium.yearly"
        fakeData["autoRenewStatus"] = true
        return fakeData
    }
    
    private func createFakeArchivedObject() -> Any {
        let fakeTransaction = NSMutableDictionary()
        fakeTransaction["productIdentifier"] = "premium.subscription"
        fakeTransaction["transactionDate"] = Date()
        fakeTransaction["transactionIdentifier"] = "fake_archived_\(UUID().uuidString)"
        fakeTransaction["originalTransactionIdentifier"] = "fake_archived_original_\(UUID().uuidString)"
        fakeTransaction["expirationDate"] = Date().addingTimeInterval(365*24*3600)
        fakeTransaction["subscriptionExpirationDate"] = Date().addingTimeInterval(365*24*3600)
        fakeTransaction["webOrderLineItemID"] = "fake_archived_web_\(UUID().uuidString)"
        fakeTransaction["subscriptionGroupIdentifier"] = "premium_group"
        fakeTransaction["purchaseDate"] = Date()
        return fakeTransaction
    }
}