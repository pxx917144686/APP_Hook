import StoreKit

enum Sk1Hooks {
	static func bootstrap() {
		_ = CanPayHook().hook()
		_ = DelegateHook().hook()
		_ = TransactionHook().hook()
	}
	
	static func priceZero() {
		_ = ProductHook().hook()
	}
}
