/**
有问题～ 联系 pxx917144686

作用是在无根越狱环境中"伪装"身份：

让APP认为正在使用的是libcrane.dylib而不是SatellaJailed.dylib 绕过某些检测机制或安全限制
*/




struct DyldHook: HookFunc {
    typealias T = @convention(c) (UInt32) -> UnsafePointer<Int8>?
    
    let name: String = "_dyld_get_image_name"
    let replace: T = { index in
        let crane: UnsafePointer<Int8> = "/var/jb/Library/MobileSubstrate/DynamicLibraries/libcrane.dylib".withCString { $0 }
        let origVal: UnsafePointer<Int8>? = orig(index)

        if let origVal, !String(cString: origVal).hasSuffix("SatellaJailed.dylib") {
            return origVal
        }
        
        return crane
    }
}