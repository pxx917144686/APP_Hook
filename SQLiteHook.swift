import Foundation
import SQLite3

// 全局变量存储原始函数指针
private var originalSQLiteExecHook: UnsafeMutableRawPointer?
private var originalSQLitePrepareHook: UnsafeMutableRawPointer?
private var originalSQLiteStepHook: UnsafeMutableRawPointer?

// 存储原始函数用于通用 Hook
private var storedOriginalSQLiteExec: (@convention(c) (OpaquePointer?, UnsafePointer<CChar>?, (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)?, UnsafeMutableRawPointer?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)?
private var storedOriginalSQLiteStep: (@convention(c) (OpaquePointer?) -> Int32)?
private var storedOriginalSQLitePrepare: (@convention(c) (OpaquePointer?, UnsafePointer<CChar>?, Int32, UnsafeMutablePointer<OpaquePointer?>?, UnsafeMutablePointer<UnsafePointer<CChar>?>?) -> Int32)?

// 全局C函数替换
@_cdecl("hooked_sqlite3_exec")
private func hooked_sqlite3_exec(
    db: OpaquePointer?,
    sql: UnsafePointer<CChar>?,
    callback: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)?,
    callbackArg: UnsafeMutableRawPointer?,
    errmsg: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    if let sqlString = sql {
        let query = String(cString: sqlString)
        print("[SQLiteHook] SQL Query: \(query)")
        
        if query.contains("transaction") || query.contains("entitlement") || query.contains("premium.full.per.year") {
            print("[SQLiteHook] Intercepted StoreKit query: \(query)")
            
            if query.lowercased().contains("select") {
                return SQLiteHook.interceptStoreKitQuery(db: db, query: query, callback: callback, callbackArg: callbackArg)
            }
        }
    }
    
    // 调用原始函数
    typealias OriginalFunc = @convention(c) (
        OpaquePointer?, 
        UnsafePointer<CChar>?,
        (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)?,
        UnsafeMutableRawPointer?,
        UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
    ) -> Int32
    
    guard let original = originalSQLiteExecHook else { return SQLITE_ERROR }
    let originalFunc = unsafeBitCast(original, to: OriginalFunc.self)
    return originalFunc(db, sql, callback, callbackArg, errmsg)
}

@_cdecl("hooked_sqlite3_prepare_v2")
private func hooked_sqlite3_prepare_v2(
    db: OpaquePointer?,
    sql: UnsafePointer<CChar>?,
    nByte: Int32,
    ppStmt: UnsafeMutablePointer<OpaquePointer?>?,
    pzTail: UnsafeMutablePointer<UnsafePointer<CChar>?>?
) -> Int32 {
    if let sqlString = sql {
        let query = String(cString: sqlString)
        if query.contains("storekit") || query.contains("transaction") || query.contains("entitlement") {
            print("[SQLiteHook] Intercepted prepare query: \(query)")
        }
    }
    
    typealias OriginalFunc = @convention(c) (
        OpaquePointer?,
        UnsafePointer<CChar>?,
        Int32,
        UnsafeMutablePointer<OpaquePointer?>?,
        UnsafeMutablePointer<UnsafePointer<CChar>?>?
    ) -> Int32
    
    guard let original = originalSQLitePrepareHook else { return SQLITE_ERROR }
    let originalFunc = unsafeBitCast(original, to: OriginalFunc.self)
    return originalFunc(db, sql, nByte, ppStmt, pzTail)
}

@_cdecl("hooked_sqlite3_step")
private func hooked_sqlite3_step(stmt: OpaquePointer?) -> Int32 {
    typealias OriginalFunc = @convention(c) (OpaquePointer?) -> Int32
    
    guard let original = originalSQLiteStepHook else { return SQLITE_ERROR }
    let originalFunc = unsafeBitCast(original, to: OriginalFunc.self)
    let result = originalFunc(stmt)
    
    if result == SQLITE_ROW {
        if let sql = sqlite3_sql(stmt) {
            let query = String(cString: sql)
            if query.contains("premium.full.per.year") || query.contains("storekit") {
                print("[SQLiteHook] StoreKit query returned row: \(query)")
            }
        }
    }
    
    return result
}

// 通用 Hook 的全局函数
@_cdecl("universal_hooked_sqlite3_exec")
private func universal_hooked_sqlite3_exec(
    db: OpaquePointer?,
    sql: UnsafePointer<CChar>?,
    callback: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)?,
    callbackArg: UnsafeMutableRawPointer?,
    errmsg: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    if let sqlString = sql {
        let query = String(cString: sqlString)
        if SQLiteUniversalHook.isStoreKitQuery(query) {
            print("[SQLite] 拦截 StoreKit 查询: \(query)")
            return SQLiteUniversalHook.handleStoreKitQuery(query, db: db, callback: callback, callbackArg: callbackArg)
        }
    }
    
    // 调用原始函数
    guard let originalFunc = storedOriginalSQLiteExec else { return SQLITE_ERROR }
    return originalFunc(db, sql, callback, callbackArg, errmsg)
}

@_cdecl("universal_hooked_sqlite3_step")
private func universal_hooked_sqlite3_step(stmt: OpaquePointer?) -> Int32 {
    guard let originalFunc = storedOriginalSQLiteStep else { return SQLITE_ERROR }
    let result = originalFunc(stmt)
    
    if result == SQLITE_ROW {
        if let sql = sqlite3_sql(stmt) {
            let query = String(cString: sql)
            if SQLiteUniversalHook.isStoreKitQuery(query) {
                print("[SQLite] StoreKit 查询结果: \(query)")
            }
        }
    }
    
    return result
}

@_cdecl("universal_hooked_sqlite3_prepare_v2")
private func universal_hooked_sqlite3_prepare_v2(
    db: OpaquePointer?,
    sql: UnsafePointer<CChar>?,
    nByte: Int32,
    ppStmt: UnsafeMutablePointer<OpaquePointer?>?,
    pzTail: UnsafeMutablePointer<UnsafePointer<CChar>?>?
) -> Int32 {
    if let sqlString = sql {
        let query = String(cString: sqlString)
        if SQLiteUniversalHook.isStoreKitQuery(query) {
            print("[SQLite] 准备 StoreKit 查询: \(query)")
        }
    }
    
    guard let originalFunc = storedOriginalSQLitePrepare else { return SQLITE_ERROR }
    return originalFunc(db, sql, nByte, ppStmt, pzTail)
}

struct SQLiteHook: Hook {
    typealias T = @convention(c) () -> Void
    var cls: AnyClass? { return nil }
    var sel: Selector { return #selector(NSObject.description) }
    var replace: T { return {} }
    
    func hook() {
        // Hook SQLite 函数以拦截 StoreKit 数据库查询
        hookSQLiteFunctions()
        
        // 直接修改 StoreKit 数据库
        modifyStoreKitDatabase()
    }
    
    private func hookSQLiteFunctions() {
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT 的值
        
        // Hook sqlite3_exec
        if let original = dlsym(rtldDefault, "sqlite3_exec") {
            print("[SQLiteHook] Found sqlite3_exec at: \(original)")
            originalSQLiteExecHook = original
            hookFunction(original: original, replacement: unsafeBitCast(hooked_sqlite3_exec, to: UnsafeMutableRawPointer.self))
        }
        
        // Hook sqlite3_prepare_v2
        if let original = dlsym(rtldDefault, "sqlite3_prepare_v2") {
            print("[SQLiteHook] Found sqlite3_prepare_v2 at: \(original)")
            originalSQLitePrepareHook = original
            hookFunction(original: original, replacement: unsafeBitCast(hooked_sqlite3_prepare_v2, to: UnsafeMutableRawPointer.self))
        }
        
        // Hook sqlite3_step
        if let original = dlsym(rtldDefault, "sqlite3_step") {
            print("[SQLiteHook] Found sqlite3_step at: \(original)")
            originalSQLiteStepHook = original
            hookFunction(original: original, replacement: unsafeBitCast(hooked_sqlite3_step, to: UnsafeMutableRawPointer.self))
        }
    }
    
    private func hookFunction(original: UnsafeMutableRawPointer, replacement: UnsafeMutableRawPointer) {
        // 内存保护
        let pageSize = Int(getpagesize())
        let page = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: original) & ~UInt(pageSize - 1))
        if let page = page {
            mprotect(page, pageSize, PROT_READ | PROT_WRITE | PROT_EXEC)
            
            // 替换函数地址
            original.assumingMemoryBound(to: UnsafeMutableRawPointer.self).pointee = replacement
            
            // 恢复内存保护
            mprotect(page, pageSize, PROT_READ | PROT_EXEC)
        }
    }
    
    static func interceptStoreKitQuery(
        db: OpaquePointer?,
        query: String,
        callback: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)?,
        callbackArg: UnsafeMutableRawPointer?
    ) -> Int32 {
        
        if query.contains("premium.full.per.year") {
            let fakeColumns = [
                strdup("product_id"),
                strdup("transaction_id"), 
                strdup("purchase_date"),
                strdup("expires_date"),
                strdup("verification_status")
            ]
            
            let fakeValues = [
                strdup("premium.full.per.year"),
                strdup("2000000000000000"),
                strdup("\(Int(Date().timeIntervalSince1970))"),
                strdup("\(Int(Date().addingTimeInterval(365*24*3600).timeIntervalSince1970))"),
                strdup("verified")
            ]
            
            let columnPointers = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: 5)
            let valuePointers = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: 5)
            
            for i in 0..<5 {
                columnPointers[i] = fakeColumns[i]
                valuePointers[i] = fakeValues[i]
            }
            
            if let callback = callback {
                _ = callback(callbackArg, 5, valuePointers, columnPointers)
            }
            
            for i in 0..<5 {
                free(fakeColumns[i])
                free(fakeValues[i])
            }
            columnPointers.deallocate()
            valuePointers.deallocate()
            
            print("[SQLiteHook] Returned fake StoreKit data")
            return SQLITE_OK
        }
        
        return SQLITE_DONE
    }
    
    private func modifyStoreKitDatabase() {
        DispatchQueue.global(qos: .background).async {
            self.findAndModifyStoreKitDB()
        }
    }
    
    private func findAndModifyStoreKitDB() {
        let possiblePaths = [
            NSHomeDirectory() + "/Library/StoreKit",
            NSHomeDirectory() + "/Documents/StoreKit", 
            NSHomeDirectory() + "/Library/Caches/StoreKit",
            NSHomeDirectory() + "/tmp/StoreKit",
            NSHomeDirectory() + "/Library/Application Support/StoreKit"
        ]
        
        for path in possiblePaths {
            let storeKitURL = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: storeKitURL.path) {
                searchForDatabases(in: storeKitURL)
            }
        }
        
        searchForDatabases(in: URL(fileURLWithPath: NSHomeDirectory()))
    }
    
    private func searchForDatabases(in directory: URL) {
        guard let enumerator = FileManager.default.enumerator(at: directory, 
                                                             includingPropertiesForKeys: [.isRegularFileKey],
                                                             options: [.skipsHiddenFiles]) else { return }
        
        for case let fileURL as URL in enumerator {
            let fileName = fileURL.lastPathComponent.lowercased()
            
            if fileName.contains("storekit") || 
               fileName.contains("transaction") ||
               fileName.contains("entitlement") ||
               fileName.hasSuffix(".db") || 
               fileName.hasSuffix(".sqlite") ||
               fileName.hasSuffix(".sqlite3") {
                
                print("[SQLiteHook] Found potential database: \(fileURL.path)")
                injectFakeTransaction(at: fileURL)
            }
        }
    }
    
    private func injectFakeTransaction(at dbURL: URL) {
        var db: OpaquePointer?
        
        let result = sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE, nil)
        
        if result == SQLITE_OK {
            print("[SQLiteHook] Successfully opened database: \(dbURL.path)")
            
            inspectDatabase(db: db)
            
            let currentTime = Int(Date().timeIntervalSince1970)
            let expirationTime = Int(Date().addingTimeInterval(365*24*3600).timeIntervalSince1970)
            
            let insertQueries = [
                """
                INSERT OR REPLACE INTO transactions 
                (product_id, transaction_id, purchase_date, expires_date, verification_status) 
                VALUES 
                ('premium.full.per.year', '2000000000000000', '\(currentTime)', '\(expirationTime)', 'verified');
                """,
                
                """
                INSERT OR REPLACE INTO entitlements 
                (productIdentifier, transactionIdentifier, purchaseDate, expirationDate, isActive) 
                VALUES 
                ('premium.full.per.year', '2000000000000000', '\(currentTime)', '\(expirationTime)', 1);
                """,
                
                """
                INSERT OR REPLACE INTO sk_transactions 
                (id, product_id, state, purchase_date, expiration_date) 
                VALUES 
                ('2000000000000000', 'premium.full.per.year', 'purchased', '\(currentTime)', '\(expirationTime)');
                """,
                
                """
                UPDATE transactions SET verification_status = 'verified', expires_date = '\(expirationTime)' 
                WHERE product_id = 'premium.full.per.year';
                """,
                
                """
                UPDATE entitlements SET isActive = 1, expirationDate = '\(expirationTime)' 
                WHERE productIdentifier = 'premium.full.per.year';
                """
            ]
            
            for query in insertQueries {
                let insertResult = sqlite3_exec(db, query, nil, nil, nil)
                if insertResult == SQLITE_OK {
                    print("[SQLiteHook] Successfully executed: \(query.prefix(50))...")
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    print("[SQLiteHook] Query failed: \(errorMsg)")
                }
            }
            
            sqlite3_close(db)
        } else {
            print("[SQLiteHook] Failed to open database: \(dbURL.path), error: \(result)")
        }
    }
    
    private func inspectDatabase(db: OpaquePointer?) {
        let tableQuery = "SELECT name FROM sqlite_master WHERE type='table';"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, tableQuery, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let tableName = sqlite3_column_text(statement, 0) {
                    let table = String(cString: tableName)
                    print("[SQLiteHook] Found table: \(table)")
                    
                    inspectTableStructure(db: db, tableName: table)
                }
            }
        }
        sqlite3_finalize(statement)
    }
    
    private func inspectTableStructure(db: OpaquePointer?, tableName: String) {
        let pragmaQuery = "PRAGMA table_info(\(tableName));"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, pragmaQuery, -1, &statement, nil) == SQLITE_OK {
            print("[SQLiteHook] Table \(tableName) structure:")
            while sqlite3_step(statement) == SQLITE_ROW {
                if let columnName = sqlite3_column_text(statement, 1) {
                    let column = String(cString: columnName)
                    print("[SQLiteHook]   Column: \(column)")
                }
            }
        }
        sqlite3_finalize(statement)
    }
}

@available(iOS 15.0, *)
class SQLiteUniversalHook {
    static func hookAllSQLiteFunctions() {
        let functions = [
            "sqlite3_open",
            "sqlite3_exec", 
            "sqlite3_prepare_v2",
            "sqlite3_step",
            "sqlite3_finalize"
        ]
        
        for funcName in functions {
            hookSQLiteFunction(name: funcName)
        }
    }
    
    private static func hookSQLiteFunction(name: String) {
        guard let original = dlsym(dlopen(nil, RTLD_NOW), name) else { return }
        
        switch name {
        case "sqlite3_exec":
            hookSQLiteExec(original: original)
        case "sqlite3_step":
            hookSQLiteStep(original: original)
        case "sqlite3_prepare_v2":
            hookSQLitePrepare(original: original)
        default:
            break
        }
    }
    
    private static func hookSQLiteExec(original: UnsafeMutableRawPointer) {
        typealias OriginalFunc = @convention(c) (OpaquePointer?, UnsafePointer<CChar>?, (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)?, UnsafeMutableRawPointer?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32
        
        // 保存原始函数
        storedOriginalSQLiteExec = unsafeBitCast(original, to: OriginalFunc.self)
        
        // 替换函数
        let newPtr = unsafeBitCast(universal_hooked_sqlite3_exec, to: UnsafeMutableRawPointer.self)
        
        // 获取页大小
        let pageSize = Int(getpagesize())
        // 计算包含函数指针的内存页的起始地址
        let page = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: original) & ~UInt(pageSize - 1))
                
        if let page = page {
            // 更改内存权限为可读、可写、可执行
            mprotect(page, pageSize, PROT_READ | PROT_WRITE | PROT_EXEC)
            
            // 替换函数指针
            original.assumingMemoryBound(to: UnsafeMutableRawPointer.self).pointee = newPtr
            
            // 恢复内存保护为只读和可执行
            mprotect(page, pageSize, PROT_READ | PROT_EXEC)
            
            print("[SQLite] Successfully hooked sqlite3_exec")
        }
    }
    
    static func isStoreKitQuery(_ query: String) -> Bool {
        let keywords = [
            "transaction", "purchase", "subscription", "receipt",
            "product_id", "transaction_id", "purchase_date",
            "expiration_date", "app_store", "storekit"
        ]
        return keywords.contains { query.lowercased().contains($0) }
    }
    
    static func handleStoreKitQuery(_ query: String, db: OpaquePointer?, callback: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)?, callbackArg: UnsafeMutableRawPointer?) -> Int32 {
        // 根据查询类型返回伪造数据
        if query.contains("SELECT") {
            return provideFakeResults(callback: callback, callbackArg: callbackArg)
        }
        return 0 // SQLITE_OK
    }
    
    private static func provideFakeResults(callback: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32)?, callbackArg: UnsafeMutableRawPointer?) -> Int32 {
        // 提供伪造的查询结果
        return 0
    }
    
    private static func hookSQLiteStep(original: UnsafeMutableRawPointer) {
        typealias OriginalFunc = @convention(c) (OpaquePointer?) -> Int32
        
        // 保存原始函数
        storedOriginalSQLiteStep = unsafeBitCast(original, to: OriginalFunc.self)
        
        let newPtr = unsafeBitCast(universal_hooked_sqlite3_step, to: UnsafeMutableRawPointer.self)
        
        // 获取页大小
        let pageSize = Int(getpagesize())
        // 计算包含函数指针的内存页的起始地址
        let page = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: original) & ~UInt(pageSize - 1))
                
        if let page = page {
            // 更改内存权限为可读、可写、可执行
            mprotect(page, pageSize, PROT_READ | PROT_WRITE | PROT_EXEC)
            
            // 替换函数指针
            original.assumingMemoryBound(to: UnsafeMutableRawPointer.self).pointee = newPtr
            
            // 恢复内存保护为只读和可执行
            mprotect(page, pageSize, PROT_READ | PROT_EXEC)
            
            print("[SQLite] Successfully hooked sqlite3_step")
        }
    }
    
    private static func hookSQLitePrepare(original: UnsafeMutableRawPointer) {
        typealias OriginalFunc = @convention(c) (OpaquePointer?, UnsafePointer<CChar>?, Int32, UnsafeMutablePointer<OpaquePointer?>?, UnsafeMutablePointer<UnsafePointer<CChar>?>?) -> Int32
        
        // 保存原始函数
        storedOriginalSQLitePrepare = unsafeBitCast(original, to: OriginalFunc.self)
        
        let newPtr = unsafeBitCast(universal_hooked_sqlite3_prepare_v2, to: UnsafeMutableRawPointer.self)
        
        // 获取页大小
        let pageSize = Int(getpagesize())
        // 计算包含函数指针的内存页的起始地址
        let page = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: original) & ~UInt(pageSize - 1))
                
        if let page = page {
            // 更改内存权限为可读、可写、可执行
            mprotect(page, pageSize, PROT_READ | PROT_WRITE | PROT_EXEC)
            
            // 替换函数指针
            original.assumingMemoryBound(to: UnsafeMutableRawPointer.self).pointee = newPtr
            
            // 恢复内存保护为只读和可执行
            mprotect(page, pageSize, PROT_READ | PROT_EXEC)
            
            print("[SQLite] Successfully hooked sqlite3_prepare_v2")
        }
    }
}