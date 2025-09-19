// of pxx917144686
// iOS 12-18 的 Jinx 兼容/增强层




import Foundation
import ObjectiveC
import UIKit



enum JinxCompat {
    // 公开的可选日志回调
    static var logHandler: ((String) -> Void)?

    static func bootstrap() {
        log("[JinxCompat] bootstrap start …")
        log("iOS: \(systemVersionString()) | arm64e: \(isArm64e()) | rootless: \(isRootless())")
        log("[JinxCompat] bootstrap done.")
    }

    // MARK: - Hook 安装辅助
    @inlinable
    static func installMessageHook(
        cls: AnyClass?,
        sel: Selector,
        replace: OpaquePointer,
        orig: inout OpaquePointer?
    ) -> Bool {
        guard let cls else { return false }

        // 1) 直接走 Jinx.Replace（首选）
        if Replace.message(cls, sel, with: replace, orig: &orig) {
            return true
        }

        // 2) 简单重试（偶发时序问题）
        for _ in 0..<2 {
            if Replace.message(cls, sel, with: replace, orig: &orig) {
                return true
            }
        }

        // 3) 降级：尝试交换实现（仅当方法存在时）
        if let method: Method = class_getInstanceMethod(cls, sel) {
            let types: UnsafePointer<Int8>? = method_getTypeEncoding(method)
            let newSel: Selector = sel_registerName("JX_" + String(cString: sel_getName(sel)))
            if class_addMethod(cls, newSel, replace, types) {
                if let newMethod: Method = class_getInstanceMethod(cls, newSel) {
                    let origImp: IMP = method_getImplementation(method)
                    // IMP 与 OpaquePointer 等价，这里做显式可选赋值
                    orig = (origImp as OpaquePointer)
                    method_exchangeImplementations(method, newMethod)
                    return true
                }
            }
        }

        log("[JinxCompat] installMessageHook failed: \(NSStringFromClass(cls)) # \(NSStringFromSelector(sel))")
        return false
    }

    // MARK: - 环境探测
    @inlinable
    static func systemVersionString() -> String {
        #if os(iOS)
        return UIDevice.current.systemVersion
        #else
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    @inlinable
    static func isArm64e() -> Bool {
        #if arch(arm64e)
        return true
        #else
        return false
        #endif
    }

    @inlinable
    static func isRootless() -> Bool {
        // 通过 Jinx 的 String.withRootPath 行为间接判断
        let test = "/usr/lib/libsubstrate.dylib"
        return test.hasPrefix("/var/jb")
    }

    // MARK: - 日志
    @inlinable
    static func log(_ message: String) {
        if let handler = logHandler {
            handler(message)
        } else {
            print(message)
        }
    }
}


