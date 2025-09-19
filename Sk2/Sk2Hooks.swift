import Foundation
import StoreKit

enum Sk2Hooks {
	@available(iOS 15.0, *)
	static func bootstrap() {
		print("[APP_hook] 启用 StoreKit 2 Hook - 专注于网络 API 拦截")
		_ = URLHook().hook()
		print("[APP_hook] StoreKit 2 Hook 完成 - 已激活网络请求拦截")
	}
}
