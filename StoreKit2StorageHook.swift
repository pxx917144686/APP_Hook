import Foundation
import StoreKit
import ObjectiveC

protocol StoreKit2HookProtocol {
    func hook()
}

@available(iOS 15.0, *)
struct StoreKit2StorageHook: StoreKit2HookProtocol {
    
    // 静态变量保存原始函数指针
    static var originalSQLiteExec: (@convention(c) (OpaquePointer?, UnsafePointer<CChar>?, (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)?, UnsafeMutableRawPointer?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)?
    static var originalSQLitePrepare: (@convention(c) (OpaquePointer?, UnsafePointer<CChar>?, Int32, UnsafeMutablePointer<OpaquePointer?>?, UnsafeMutablePointer<UnsafePointer<CChar>?>?) -> Int32)?
    static var originalSQLiteStep: (@convention(c) (OpaquePointer?) -> Int32)?
    static var originalSQLiteFinalize: (@convention(c) (OpaquePointer?) -> Int32)?
    
    func hook() {
        hookSQLiteOperations()
        hookStoreKitStorage()
        hookReceiptStorage()
    }
    
    private func hookSQLiteOperations() {
        guard let handle = dlopen(nil, RTLD_NOW) else {
            print("[SatellaJailed] 获取动态库句柄失败")
            return
        }
        
        // Hook SQLite相关函数并保存原始指针
        if let execPtr = dlsym(handle, "sqlite3_exec") {
            Self.originalSQLiteExec = unsafeBitCast(execPtr, to: (@convention(c) (OpaquePointer?, UnsafePointer<CChar>?, (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)?, UnsafeMutableRawPointer?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32).self)
        }
        
        if let preparePtr = dlsym(handle, "sqlite3_prepare_v2") {
            Self.originalSQLitePrepare = unsafeBitCast(preparePtr, to: (@convention(c) (OpaquePointer?, UnsafePointer<CChar>?, Int32, UnsafeMutablePointer<OpaquePointer?>?, UnsafeMutablePointer<UnsafePointer<CChar>?>?) -> Int32).self)
        }
        
        if let stepPtr = dlsym(handle, "sqlite3_step") {
            Self.originalSQLiteStep = unsafeBitCast(stepPtr, to: (@convention(c) (OpaquePointer?) -> Int32).self)
        }
        
        if let finalizePtr = dlsym(handle, "sqlite3_finalize") {
            Self.originalSQLiteFinalize = unsafeBitCast(finalizePtr, to: (@convention(c) (OpaquePointer?) -> Int32).self)
        }
        
        print("[SatellaJailed] SQLite原始函数指针已保存")
        hookSQLiteExecution()
    }
    
    private func hookSQLiteExecution() {
        let sqliteSymbols = [
            "sqlite3_exec",
            "sqlite3_prepare_v2",
            "sqlite3_step",
            "sqlite3_finalize"
        ]
        
        for symbol in sqliteSymbols {
            if let original = dlsym(dlopen(nil, RTLD_NOW), symbol) {
                let ptrValue = UInt(bitPattern: original)
                let highBits = (ptrValue >> 48) & 0xFFFF
                
                if highBits != 0 {
                    print("[SatellaJailed] 检测到PAC保护的指针: \(symbol)")
                    handlePACProtectedPointer(original, symbol: symbol)
                } else {
                    print("[SatellaJailed] 普通指针: \(symbol)")
                    handleNormalPointer(original, symbol: symbol)
                }
            }
        }
    }
    
    private func handlePACProtectedPointer(_ pointer: UnsafeMutableRawPointer, symbol: String) {
        let maskedPointer = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: pointer) & 0x0000FFFFFFFFFFFF)
        
        if let validPointer = maskedPointer {
            print("[SatellaJailed] PAC指针掩码处理成功: \(symbol)")
            setupHookForPointer(validPointer, symbol: symbol)
        } else {
            print("[SatellaJailed] PAC指针掩码处理失败: \(symbol)")
        }
    }
    
    private func handleNormalPointer(_ pointer: UnsafeMutableRawPointer, symbol: String) {
        setupHookForPointer(pointer, symbol: symbol)
    }
    
    // 修复 StoreKit2StorageHook 的指针问题
    private func setupHookForPointer(_ pointer: UnsafeMutableRawPointer, symbol: String) {
        var originalPtr: UnsafeMutableRawPointer? = pointer
        
        let replacement: UnsafeMutableRawPointer
        
        switch symbol {
        case "sqlite3_exec":
            replacement = unsafeBitCast(sqlite3_exec_replacement, to: UnsafeMutableRawPointer.self)
        case "sqlite3_prepare_v2":
            replacement = unsafeBitCast(sqlite3_prepare_v2_replacement, to: UnsafeMutableRawPointer.self)
        case "sqlite3_step":
            replacement = unsafeBitCast(sqlite3_step_replacement, to: UnsafeMutableRawPointer.self)
        case "sqlite3_finalize":
            replacement = unsafeBitCast(sqlite3_finalize_replacement, to: UnsafeMutableRawPointer.self)
        default:
            print("[SatellaJailed] 未知的SQLite符号: \(symbol)")
            return
        }
        
        withUnsafeMutablePointer(to: &originalPtr) { ptr in
            let hook = RebindHook(
                name: symbol,
                replace: replacement,
                orig: ptr
            )
            
            if Rebind(hook: hook).rebind() {
                print("[SatellaJailed] 成功Hook SQLite函数: \(symbol)")
            } else {
                print("[SatellaJailed] Hook SQLite函数失败: \(symbol)")
            }
        }
    }
    
    private func hookStoreKitStorage() {
        print("[SatellaJailed] 设置StoreKit存储Hook")
        
        let storeKitStorageSymbols = [
            "_$s8StoreKit11TransactionV7storageACvgZ",
            "_$s8StoreKit7ProductV7storageACvgZ"
        ]
        
        for symbol in storeKitStorageSymbols {
            if let original = dlsym(dlopen(nil, RTLD_NOW), symbol) {
                var originalPtr: UnsafeMutableRawPointer? = UnsafeMutableRawPointer(mutating: original)
                
                withUnsafeMutablePointer(to: &originalPtr) { ptr in
                    let hook = RebindHook(
                        name: "StoreKit_\(symbol)",
                        replace: unsafeBitCast(storeKitStorageReplacement, to: UnsafeMutableRawPointer.self),
                        orig: ptr
                    )
                    
                    if Rebind(hook: hook).rebind() {
                        print("[SatellaJailed] 成功Hook StoreKit存储: \(symbol)")
                    } else {
                        print("[SatellaJailed] Hook StoreKit存储失败: \(symbol)")
                    }
                }
            }
        }
    }
    
    private func hookReceiptStorage() {
        print("[SatellaJailed] 设置收据存储Hook")
        
        let receiptSymbols = [
            "_$s8StoreKit10AppReceipt7storageACvgZ",
            "_$s8StoreKit15ReceiptRefreshO7requestyyYaKFZ"
        ]
        
        for symbol in receiptSymbols {
            if let original = dlsym(dlopen(nil, RTLD_NOW), symbol) {
                var originalPtr: UnsafeMutableRawPointer? = UnsafeMutableRawPointer(mutating: original)
                
                withUnsafeMutablePointer(to: &originalPtr) { ptr in
                    let hook = RebindHook(
                        name: "Receipt_\(symbol)",
                        replace: unsafeBitCast(receiptStorageReplacement, to: UnsafeMutableRawPointer.self),
                        orig: ptr
                    )
                    
                    if Rebind(hook: hook).rebind() {
                        print("[SatellaJailed] 成功Hook收据存储: \(symbol)")
                    } else {
                        print("[SatellaJailed] Hook收据存储失败: \(symbol)")
                    }
                }
            }
        }
    }
}

// SQLite替换函数
@available(iOS 15.0, *)
@_cdecl("sqlite3_exec_replacement")
func sqlite3_exec_replacement(
    _ db: OpaquePointer?,
    _ sql: UnsafePointer<CChar>?,
    _ callback: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)?,
    _ firstArg: UnsafeMutableRawPointer?,
    _ errmsg: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    
    if let sqlString = sql {
        let query = String(cString: sqlString)
        print("[SatellaJailed] SQLite执行被拦截: \(query)")
        
        if isStoreKitRelatedQuery(query) {
            print("[SatellaJailed] 拦截StoreKit SQLite查询")
            return 0 // 成功返回，阻止实际查询
        }
    }
    
    // 调用原始函数
    if let original = StoreKit2StorageHook.originalSQLiteExec {
        return original(db, sql, callback, firstArg, errmsg)
    }
    
    return 0 // 如果没有原始函数，返回成功
}

@available(iOS 15.0, *)
@_cdecl("sqlite3_prepare_v2_replacement")
func sqlite3_prepare_v2_replacement(
    _ db: OpaquePointer?,
    _ zSql: UnsafePointer<CChar>?,
    _ nByte: Int32,
    _ ppStmt: UnsafeMutablePointer<OpaquePointer?>?,
    _ pzTail: UnsafeMutablePointer<UnsafePointer<CChar>?>?
) -> Int32 {
    
    if let sqlString = zSql {
        let query = String(cString: sqlString)
        print("[SatellaJailed] SQLite准备语句被拦截: \(query)")
        
        if isStoreKitRelatedQuery(query) {
            print("[SatellaJailed] 拦截StoreKit SQLite准备语句")
            // 创建一个假的statement指针
            if let stmt = ppStmt {
                stmt.pointee = nil
            }
            return 0 // 成功返回
        }
    }
    
    // 调用原始函数
    if let original = StoreKit2StorageHook.originalSQLitePrepare {
        return original(db, zSql, nByte, ppStmt, pzTail)
    }
    
    return 0
}

@available(iOS 15.0, *)
@_cdecl("sqlite3_step_replacement")
func sqlite3_step_replacement(_ stmt: OpaquePointer?) -> Int32 {
    print("[SatellaJailed] SQLite步进被拦截")
    
    if let original = StoreKit2StorageHook.originalSQLiteStep {
        return original(stmt)
    }
    
    return 101 // SQLITE_DONE 如果没有原始函数
}

@available(iOS 15.0, *)
@_cdecl("sqlite3_finalize_replacement")
func sqlite3_finalize_replacement(_ stmt: OpaquePointer?) -> Int32 {
    print("[SatellaJailed] SQLite完成被拦截")
    
    // 调用原始函数清理资源
    if let original = StoreKit2StorageHook.originalSQLiteFinalize {
        return original(stmt)
    }
    
    return 0 // 成功
}

@available(iOS 15.0, *)
@_cdecl("storeKitStorageReplacement")
func storeKitStorageReplacement() -> UnsafeMutableRawPointer? {
    print("[SatellaJailed] StoreKit存储被拦截")
    
    let fakeStorage = NSMutableDictionary()
    fakeStorage["transactions"] = StoreKit2FunctionHook.createFakeTransactionCollection()
    fakeStorage["products"] = []
    fakeStorage["isValid"] = true
    
    return Unmanaged.passRetained(fakeStorage as AnyObject).toOpaque()
}

@available(iOS 15.0, *)
@_cdecl("receiptStorageReplacement")
func receiptStorageReplacement() -> UnsafeMutableRawPointer? {
    print("[SatellaJailed] 收据存储被拦截")
    
    let fakeReceipt = NSMutableDictionary()
    fakeReceipt["receipt-data"] = "fake_receipt_data"
    fakeReceipt["status"] = 0
    fakeReceipt["environment"] = "Production"
    fakeReceipt["latest_receipt"] = "fake_latest_receipt"
    
    return Unmanaged.passRetained(fakeReceipt as AnyObject).toOpaque()
}

// MARK: - 辅助函数
@available(iOS 15.0, *)
func isStoreKitRelatedQuery(_ query: String) -> Bool {
    let storeKitKeywords = [
        "transaction",
        "purchase", 
        "receipt",
        "subscription",
        "product",
        "entitlement",
        "app_store",
        "storekit",
        "iap_", // In-App Purchase前缀
        "sk_", // StoreKit前缀
        "purchase_date",
        "expiration_date",
        "product_id",
        "transaction_id"
    ]
    
    let lowercaseQuery = query.lowercased()
    return storeKitKeywords.contains { lowercaseQuery.contains($0) }
}

// MARK: - StoreKit2HookProtocol扩展
@available(iOS 15.0, *)
extension StoreKit2StorageHook {
    
    func verifyStorageHookStatus() {
        print("[SatellaJailed] 验证存储Hook状态:")
        print("- SQLite可用: \(dlsym(dlopen(nil, RTLD_NOW), "sqlite3_exec") != nil)")
        print("- 原始SQLiteExec保存: \(Self.originalSQLiteExec != nil)")
        print("- 原始SQLitePrepare保存: \(Self.originalSQLitePrepare != nil)")
        print("- 原始SQLiteStep保存: \(Self.originalSQLiteStep != nil)")
        print("- 原始SQLiteFinalize保存: \(Self.originalSQLiteFinalize != nil)")
    }
    
    func resetStorageHooks() {
        print("[SatellaJailed] 重置存储Hook")
        Self.originalSQLiteExec = nil
        Self.originalSQLitePrepare = nil
        Self.originalSQLiteStep = nil
        Self.originalSQLiteFinalize = nil
    }
}