import StoreKit

enum Sk1Hooks {
	static func bootstrap() {
		CanPayHook().hook()
		DelegateHook().hook()
		TransactionHook().hook()
	}
	
	static func priceZero() {
		ProductHook().hook()
	}
}
