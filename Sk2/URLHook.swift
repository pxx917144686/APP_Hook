import Foundation

struct URLHook: Hook {
    typealias URLHandler = @Sendable (Data?, URLResponse?, Error?) -> Void
    typealias T = @convention(c) (URLSession, Selector, URLRequest, @escaping (URLHandler)) -> URLSessionDataTask

    let cls: AnyClass? = URLSession.self
    let sel: Selector = sel_registerName("dataTaskWithRequest:completionHandler:")
    
    // 处理规则
    static var appRules: [String: AppRule] = [:]

    // 专注于网络 API 拦截 - StoreKit 2 和第三方验证
    static var interceptPatterns: [String] = [
        // Apple StoreKit 2 官方 API
        "api.storekit.itunes.apple.com",           // 生产环境
        "api.storekit-sandbox.itunes.apple.com",   // 沙盒环境
        "buy.itunes.apple.com",                    // 购买验证
        "sandbox.itunes.apple.com",                // 沙盒购买验证
        
        // StoreKit 2 API 路径
        "/v1/subscriptions/",                      // 订阅查询
        "/v1/transactions/",                       // 交易查询
        "/v1/history/",                           // 历史查询
        "/v1/status/",                            // 状态查询
        "/v1/notifications/",                     // 通知查询
        "/v1/subscription-groups/",               // 订阅组查询
        "/v1/offer-eligibility/",                 // 试用资格查询
        "/v1/subscription-offers/",               // 订阅优惠查询
        "/v1/refund-lookup/",                     // 退款查询
        "/v1/consumption-request/",               // 消费请求
        "/v1/extend-renewal-date/",               // 续期延期
        "/v1/mass-extend-renewal-date/",          // 批量续期延期
        "/v1/request-refund/",                    // 退款请求
        "/v1/request-test-notification/",         // 测试通知
        "/v1/notifications/history/",             // 通知历史
        "/v1/notifications/test/",                // 测试通知
        
        // 第三方验证 API 模式
        "/verifyReceipt",          // Apple官方收据验证
        "/itunesreceipt",          // 通用iTunes收据验证
        "/receipt/verify",         // 常见的收据验证路径
        "/api/verify",             // API验证端点
        "/subscription/check",     // 订阅检查端点
        "/validateReceipt",        // 第三方验证端点
        "/users/validate",         // 用户验证端点
        "/v1/users/",              // 版本化API
        "/premium/check",          // 高级版检查
        "/license/verify",         // 许可证验证
        "/auth/verify",            // 认证验证
        "/payment/verify",         // 支付验证
        "/billing/check",          // 账单检查
        "/subscription/status",    // 订阅状态
        "/user/subscription",      // 用户订阅
        "/purchase/verify",        // 购买验证
        "/entitlement/check",      // 权限检查
        "/trial/check",            // 试用检查
        "/pro/check",              // 专业版检查
        "/upgrade/check"           // 升级检查
    ]
    
    let replace: T = { obj, sel, request, handler in
        guard let url = request.url?.absoluteString else {
            return Self.orig(obj, sel, request, handler)
        }
        
        let shouldIntercept = URLHook.interceptPatterns.contains { pattern in
            url.contains(pattern)
        }
        if shouldIntercept {
            print("[URLHook] 🎯 命中拦截: \(url)")
            print("[URLHook] 📱 Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
            if let method = request.httpMethod {
                print("[URLHook] 🔧 HTTP Method: \(method)")
            }
        }
        
        if shouldIntercept {
            let newHandler: URLHandler = { (originalData, response, error) in
                let fakeData = URLHook.generateIntelligentResponse(
                    request: request,
                    originalData: originalData
                )
                handler(fakeData, response, error)
            }
            
            return Self.orig(obj, sel, request, newHandler)
        }

        return Self.orig(obj, sel, request, handler)
    }
    
    // 智能响应生成
    private static func generateIntelligentResponse(request: URLRequest, originalData: Data?) -> Data? {
        let url = request.url?.absoluteString ?? ""
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let userAgent = request.value(forHTTPHeaderField: "User-Agent") ?? ""
        
        print("[URLHook] 🔍 分析请求: \(url)")
        print("[URLHook] 📱 Bundle: \(bundleId)")
        
        // 解析原始响应
        var responseData: [String: Any] = [:]
        if let data = originalData,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            responseData = json
        }
        
        // 1. 优先处理 StoreKit 2 官方 API
        if let storeKit2Response = handleStoreKit2Verification(url: url, data: originalData) {
            return storeKit2Response
        }
        
        // 2. 处理第三方验证 API
        if let thirdPartyResponse = handleThirdPartyAPI(url: url, originalData: originalData, responseData: responseData) {
            return thirdPartyResponse
        }
        
        // 3. 处理应用特定的验证逻辑
        if let appSpecificResponse = handleAppSpecificValidation(url: url, bundleId: bundleId, userAgent: userAgent, responseData: responseData) {
            return appSpecificResponse
        }
        
        // 4. 通用处理逻辑
        return generateGenericResponse(url: url, bundleId: bundleId, responseData: responseData)
    }
    
    // 处理第三方验证 API
    private static func handleThirdPartyAPI(url: String, originalData: Data?, responseData: [String: Any]) -> Data? {
        // 精确识别 API 类型，然后智能处理
        
        // 1. 识别验证 API 的类型
        let apiType = identifyVerificationAPIType(url: url)
        
        // 2. 根据类型进行智能处理
        switch apiType {
        case .subscriptionStatus:
            return handleSubscriptionStatusAPI(responseData: responseData)
        case .userInfo:
            return handleUserInfoAPI(responseData: responseData)
        case .receiptValidation:
            return handleReceiptValidationAPI(responseData: responseData)
        case .vipStatus:
            return handleVipStatusAPI(responseData: responseData)
        case .graphql:
            return handleGraphQLAPI(responseData: responseData)
        case .unknown:
            return nil
        }
    }
    
    // 识别验证 API 的类型 
    private static func identifyVerificationAPIType(url: String) -> VerificationAPIType {
        // 但不是生搬硬套具体域名
        
        if url.contains("/subscription/") || url.contains("/subscriber/") {
            return .subscriptionStatus
        }
        
        if url.contains("/user/") || url.contains("/me") || url.contains("/getUser") {
            return .userInfo
        }
        
        if url.contains("/receipt/") || url.contains("/verify") {
            return .receiptValidation
        }
        
        if url.contains("/vip/") || url.contains("/premium/") || url.contains("/status") {
            return .vipStatus
        }
        
        if url.contains("/graphql") {
            return .graphql
        }
        
        return .unknown
    }
    
    enum VerificationAPIType {
        case subscriptionStatus
        case userInfo
        case receiptValidation
        case vipStatus
        case graphql
        case unknown
    }
    
    // 处理订阅状态 API 
    private static func handleSubscriptionStatusAPI(responseData: [String: Any]) -> Data? {
        var result = responseData
        
        // 保持原有结构，只修改关键字段
        result["success"] = true
        result["status"] = "active"
        result["cancelled"] = false
        result["expiresDate"] = "2099-12-31T23:59:59Z"
        result["inTrial"] = true
        
        // 如果有 products 数组，确保第一个产品是有效的
        if var products = result["products"] as? [[String: Any]], !products.isEmpty {
            products[0]["cancelled"] = false
            products[0]["expiresDate"] = "2099-12-31T23:59:59Z"
            products[0]["inTrial"] = true
            result["products"] = products
        }
        
        print("[URLHook] 🎯 订阅状态 API 处理完成")
        return try? JSONSerialization.data(withJSONObject: result)
    }
    
    // 处理用户信息 API 
    private static func handleUserInfoAPI(responseData: [String: Any]) -> Data? {
        var result = responseData
        
        // 保持原有结构，只修改关键字段
        if result["data"] == nil { result["data"] = [:] }
        var data = result["data"] as! [String: Any]
        
        // 通用的 VIP 状态字段
        data["is_vip"] = true
        data["vip"] = true
        data["premium"] = true
        data["subscribed"] = true
        data["vip_expire"] = "2099-12-31T23:59:59Z"
        data["vip_expire_at"] = "2099-12-31T23:59:59Z"
        data["vip_expire_date"] = "2099-12-31T23:59:59Z"
        
        // 如果有 rights 字段，也进行相应修改
        if data["rights"] != nil {
            var rights = data["rights"] as! [String: Any]
            rights["vip_type"] = "premium"
            rights["vip_remainder_day"] = 999999
            rights["expires_date"] = 3250333800000
            rights["isTrialPeriod"] = false
            data["rights"] = rights
        }
        
        result["data"] = data
        
        print("[URLHook] 🎯 用户信息 API 处理完成")
        return try? JSONSerialization.data(withJSONObject: result)
    }
    
    // 处理收据验证 API 
    private static func handleReceiptValidationAPI(responseData: [String: Any]) -> Data? {
        var result = responseData
        
        // 保持原有结构，只修改关键字段
        result["status"] = 0  // Apple 收据验证成功状态
        result["environment"] = "Production"
        
        // 如果有 receipt 字段，确保其结构正确
        if result["receipt"] != nil {
            var receipt = result["receipt"] as! [String: Any]
            receipt["receipt_type"] = "Production"
            receipt["bundle_id"] = Bundle.main.bundleIdentifier ?? "unknown"
            result["receipt"] = receipt
        }
        
        print("[URLHook] 🎯 收据验证 API 处理完成")
        return try? JSONSerialization.data(withJSONObject: result)
    }
    
    // 处理 VIP 状态 API 
    private static func handleVipStatusAPI(responseData: [String: Any]) -> Data? {
        var result = responseData
        
        // 保持原有结构，只修改关键字段
        result["vip"] = true
        result["svip"] = true
        result["premium"] = true
        result["is_vip"] = true
        result["is_free_vip"] = true
        result["show_free_vip_dialog"] = true
        result["expire"] = 1893456000000  // 2099年的时间戳
        result["svipExpire"] = 1893456000000
        result["vip_expire_at"] = "2099-12-31T23:59:59Z"
        result["vip_expire_date"] = "2099-12-31T23:59:59Z"
        
        // 如果有 data 字段，也进行相应修改
        if result["data"] != nil {
            var data = result["data"] as! [String: Any]
            data["vip"] = true
            data["premium"] = true
            data["is_vip"] = true
            data["vip_expire_at"] = "2099-12-31T23:59:59Z"
            data["vip_expire_date"] = "2099-12-31T23:59:59Z"
            result["data"] = data
        }
        
        print("[URLHook] 🎯 VIP 状态 API 处理完成")
        return try? JSONSerialization.data(withJSONObject: result)
    }
    
    // 处理 GraphQL API 
    private static func handleGraphQLAPI(responseData: [String: Any]) -> Data? {
        var result = responseData
        
        // 保持原有结构，只修改关键字段
        // GraphQL 响应通常有 data 字段包含查询结果
        
        if result["data"] != nil {
            var data = result["data"] as! [String: Any]
            
            // 通用的会员状态字段修改
            data["free"] = true
            data["isSchoolAgeMember"] = true
            data["isNormalMember"] = true
            data["baseMemberAvailable"] = false
            data["expiresAt"] = "2099年9月9日"
            
            // 如果有 selectedKid 字段，也进行相应修改
            if data["selectedKid"] != nil {
                var selectedKid = data["selectedKid"] as! [String: Any]
                selectedKid["schoolAgeMember"] = [
                    "expiresAt": "2099年9月9日",
                    "__typename": "Member"
                ]
                data["selectedKid"] = selectedKid
            }
            
            result["data"] = data
        }
        
        print("[URLHook] 🎯 GraphQL API 处理完成")
        return try? JSONSerialization.data(withJSONObject: result)
    }
    
    
    // 处理应用特定的验证逻辑
    private static func handleAppSpecificValidation(url: String, bundleId: String, userAgent: String, responseData: [String: Any]) -> Data? {
        
        // 1. 识别应用类型
        let appType = identifyAppType(bundleId: bundleId, userAgent: userAgent)
        
        // 2. 根据应用类型进行通用处理
        switch appType {
        case .audioApp:
            return handleAudioAppAPI(responseData: responseData)
        case .productivityApp:
            return handleProductivityAppAPI(responseData: responseData)
        case .educationApp:
            return handleEducationAppAPI(responseData: responseData)
        case .unknown:
            return nil
        }
    }
    
    // 识别应用类型 
    private static func identifyAppType(bundleId: String, userAgent: String) -> AppType {
        
        if bundleId.contains("audio") || bundleId.contains("music") || bundleId.contains("sound") {
            return .audioApp
        }
        
        if bundleId.contains("productivity") || bundleId.contains("work") || bundleId.contains("office") {
            return .productivityApp
        }
        
        if bundleId.contains("education") || bundleId.contains("learn") || bundleId.contains("study") {
            return .educationApp
        }
        
        return .unknown
    }
    
    enum AppType {
        case audioApp
        case productivityApp
        case educationApp
        case unknown
    }
    
    // 处理音频应用 API 
    private static func handleAudioAppAPI(responseData: [String: Any]) -> Data? {
        var result = responseData
        
        // 保持原有结构，只修改关键字段
        result["status"] = "0"
        result["success"] = true
        result["premium"] = true
        result["lifetime"] = true
        
        // 如果有 receipt-data 字段，确保其结构正确
        if result["receipt-data"] != nil {
            var receiptData = result["receipt-data"] as! [String: Any]
            receiptData["status"] = 0
            receiptData["environment"] = "Production"
            result["receipt-data"] = receiptData
        }
        
        print("[URLHook] 🎯 音频应用 API 处理完成")
        return try? JSONSerialization.data(withJSONObject: result)
    }
    
    // 处理生产力应用 API
    private static func handleProductivityAppAPI(responseData: [String: Any]) -> Data? {
        var result = responseData
        
        // 保持原有结构，只修改关键字段
        if result["subscriber"] == nil { result["subscriber"] = [:] }
        var subscriber = result["subscriber"] as! [String: Any]
        if subscriber["entitlements"] == nil { subscriber["entitlements"] = [:] }
        var entitlements = subscriber["entitlements"] as! [String: Any]
        
        // 通用的生产力应用权限
        entitlements["pro"] = [
            "expires_date": "2099-12-31T23:59:59Z",
            "product_identifier": "pro_lifetime",
            "purchase_date": "2023-09-09T09:09:09Z"
        ]
        
        entitlements["premium"] = [
            "expires_date": "2099-12-31T23:59:59Z",
            "product_identifier": "premium_lifetime",
            "purchase_date": "2023-09-09T09:09:09Z"
        ]
        
        subscriber["entitlements"] = entitlements
        result["subscriber"] = subscriber
        
        print("[URLHook] 🎯 生产力应用 API 处理完成")
        return try? JSONSerialization.data(withJSONObject: result)
    }
    
    // 处理教育应用 API
    private static func handleEducationAppAPI(responseData: [String: Any]) -> Data? {
        var result = responseData
        
        // 保持原有结构，只修改关键字段
        result["vip"] = true
        result["premium"] = true
        result["is_vip"] = true
        result["vip_expire"] = "2099-12-31T23:59:59Z"
        result["vip_day"] = 99999
        
        // 如果有 data 字段，也进行相应修改
        if result["data"] != nil {
            var data = result["data"] as! [String: Any]
            data["vip"] = true
            data["premium"] = true
            data["is_vip"] = true
            data["vip_expire"] = "2099-12-31T23:59:59Z"
            result["data"] = data
        }
        
        print("[URLHook] 🎯 教育应用 API 处理完成")
        return try? JSONSerialization.data(withJSONObject: result)
    }
    
    // 通用响应生成
    private static func generateGenericResponse(url: String, bundleId: String, responseData: [String: Any]) -> Data? {
        var result = responseData
        if result.isEmpty {
            result = [:]
        }
        
        // 通用成功字段
        result["success"] = true
        result["status"] = "active"
        result["premium"] = true
        result["subscribed"] = true
        result["valid"] = true
        result["expires"] = "2099-12-31T23:59:59Z"
        result["trial"] = true
        result["pro"] = true
        
        // 如果原响应有特定字段，保持其结构但修改值
        if result["data"] != nil {
            var data = result["data"] as? [String: Any] ?? [:]
            data["premium"] = true
            data["valid"] = true
            result["data"] = data
        }
        
        if result["user"] != nil {
            var user = result["user"] as? [String: Any] ?? [:]
            user["premium"] = true
            user["subscribed"] = true
            result["user"] = user
        }
        
        print("[URLHook] 🎯 通用响应生成完成")
        return try? JSONSerialization.data(withJSONObject: result)
    }
    
    // 查找匹配的规则
    private static func findMatchingRule(bundleId: String, userAgent: String) -> AppRule? {
        for (key, rule) in appRules {
            let regex = try? NSRegularExpression(pattern: "^" + key, options: .caseInsensitive)
            let bundleRange = NSRange(location: 0, length: bundleId.count)
            let uaRange = NSRange(location: 0, length: userAgent.count)
            
            if regex?.firstMatch(in: bundleId, range: bundleRange) != nil ||
               regex?.firstMatch(in: userAgent, range: uaRange) != nil {
                return rule
            }
        }
        return nil
    }
    
    // 根据规则处理响应
    private static func processWithRule(rule: AppRule, bundleId: String, responseData: [String: Any]) -> Data? {
        var result = responseData
        
        // 构建收据数据
        let receiptData = createReceiptData(productId: rule.productId, bundleId: bundleId)
        
        // 根据处理模式生成数据
        let inAppData: [[String: Any]]
        switch rule.mode {
        case .timea:
            inAppData = [addExpirationToReceipt(receiptData)]
        case .timeb:
            inAppData = [receiptData]
        case .timec:
            inAppData = []
        case .timed:
            if let secondId = rule.secondProductId {
                inAppData = [
                    addExpirationToReceipt(updateProductId(receiptData, productId: secondId)),
                    addExpirationToReceipt(receiptData)
                ]
            } else {
                inAppData = [addExpirationToReceipt(receiptData)]
            }
        }

        // APP类型
        switch rule.handleType {
        case .hxpda:
            if result["receipt"] == nil { result["receipt"] = [:] }
            var receipt = result["receipt"] as! [String: Any]
            receipt["in_app"] = inAppData
            result["receipt"] = receipt
            result["latest_receipt_info"] = inAppData
            result["pending_renewal_info"] = [createPendingRenewalInfo(productId: rule.productId)]
            result["latest_receipt"] = rule.latestReceipt
            
        case .hxpdb:
            if result["receipt"] == nil { result["receipt"] = [:] }
            var receipt = result["receipt"] as! [String: Any]
            receipt["in_app"] = inAppData
            result["receipt"] = receipt
            
        case .hxpdc:
            let xreceipt: [String: Any] = [
                "expires_date_formatted": "2099-09-09 09:09:09 Etc/GMT",
                "expires_date": "4092599349000",
                "expires_date_formatted_pst": "2099-09-09 06:06:06 America/Los_Angeles",
                "product_id": rule.productId
            ]
            if result["receipt"] == nil { result["receipt"] = [:] }
            var receipt = result["receipt"] as! [String: Any]
            receipt.merge(xreceipt) { _, new in new }
            result["receipt"] = receipt
            result["latest_receipt_info"] = receipt
            result["status"] = 0
            result["auto_renew_status"] = 1
            result["auto_renew_product_id"] = rule.productId
            result.removeValue(forKey: "latest_expired_receipt_info")
            result.removeValue(forKey: "expiration_intent")
        }
        
        return try? JSONSerialization.data(withJSONObject: result)
    }
    
    // anchor=false逻辑
    private static func generateFallbackResponse(bundleId: String, responseData: [String: Any]) -> Data? {
        var result = responseData
        let yearlyId = "\(bundleId).yearly"
        let receiptData = createReceiptData(productId: yearlyId, bundleId: bundleId)
        let inAppData = [addExpirationToReceipt(receiptData)]
        
        if result["receipt"] == nil { result["receipt"] = [:] }
        var receipt = result["receipt"] as! [String: Any]
        receipt["in_app"] = inAppData
        result["receipt"] = receipt
        result["latest_receipt_info"] = inAppData
        result["pending_renewal_info"] = [createPendingRenewalInfo(productId: yearlyId)]
        result["latest_receipt"] = "pxx917144686"
        
        return try? JSONSerialization.data(withJSONObject: result)
    }
    
    private static func createReceiptData(productId: String, bundleId: String) -> [String: Any] {
        return [
            "quantity": "1",
            "purchase_date_ms": "1694250549000",
            "is_in_intro_offer_period": "false",
            "transaction_id": "490001314520000",
            "is_trial_period": "false",
            "original_transaction_id": "490001314520000",
            "purchase_date": "2023-09-09 09:09:09 Etc/GMT",
            "product_id": productId,
            "original_purchase_date_pst": "2023-09-09 02:09:10 America/Los_Angeles",
            "in_app_ownership_type": "PURCHASED",
            "original_purchase_date_ms": "1694250550000",
            "web_order_line_item_id": "490000123456789",
            "purchase_date_pst": "2023-09-09 02:09:09 America/Los_Angeles",
            "original_purchase_date": "2023-09-09 09:09:10 Etc/GMT"
        ]
    }
    
    private static func addExpirationToReceipt(_ receipt: [String: Any]) -> [String: Any] {
        var result = receipt
        result["expires_date"] = "2099-09-09 09:09:09 Etc/GMT"
        result["expires_date_pst"] = "2099-09-09 06:06:06 America/Los_Angeles"
        result["expires_date_ms"] = "4092599349000"
        return result
    }
    
    private static func updateProductId(_ receipt: [String: Any], productId: String) -> [String: Any] {
        var result = receipt
        result["product_id"] = productId
        return result
    }
    
    private static func createPendingRenewalInfo(productId: String) -> [String: Any] {
        return [
            "product_id": productId,
            "original_transaction_id": "490001314520000",
            "auto_renew_product_id": productId,
            "auto_renew_status": "1"
        ]
    }
}

struct AppRule {
    let mode: ProcessMode
    let handleType: HandleType
    let productId: String
    let secondProductId: String?
    let latestReceipt: String
    let version: String?
    
    enum ProcessMode {
        case timea, timeb, timec, timed
    }
    
    enum HandleType {
        case hxpda, hxpdb, hxpdc
    }
}

extension URLHook {
    static func addAppRule(appIdentifier: String, rule: AppRule) {
        appRules[appIdentifier] = rule
    }
    
    static func addInterceptPattern(_ pattern: String) {
        if !interceptPatterns.contains(pattern) {
            interceptPatterns.append(pattern)
        }
    }
    
    // 第三方验证响应模板
    private static var thirdPartyResponseTemplates: [String: [String: Any]] = [:]
    
    // 第三方验证响应模板
    static func addThirdPartyResponse(urlPattern: String, responseTemplate: [String: Any]) {
        thirdPartyResponseTemplates[urlPattern] = responseTemplate
    }
    
    // 获取自定义响应模板
    private static func getCustomResponseTemplate(for url: String) -> [String: Any]? {
        for (pattern, template) in thirdPartyResponseTemplates {
            if url.contains(pattern) {
                return template
            }
        }
        return nil
    }
    
    // 处理 StoreKit 2 的服务器验证
    private static func handleStoreKit2Verification(url: String, data: Data?) -> Data? {
        // 检查是否是 StoreKit 2 的 App Store Server API 请求
        
        // 检查是否为 StoreKit 2 相关请求
        let isStoreKit2Request = url.contains("api.storekit.itunes.apple.com") ||
                                url.contains("api.storekit-sandbox.itunes.apple.com") ||
                                url.contains("buy.itunes.apple.com") ||
                                url.contains("sandbox.itunes.apple.com") ||
                                url.contains("/v1/subscriptions/") ||
                                url.contains("/v1/transactions/") ||
                                url.contains("/v1/offer-eligibility/") ||
                                url.contains("/v1/subscription-offers/")
        
        guard isStoreKit2Request else {
            return nil
        }
        
        print("[SatellaJailed] 拦截到 StoreKit 2 请求: \(url)")
        
        // 根据请求类型返回不同的伪造响应
        if url.contains("/v1/offer-eligibility/") {
            // 试用资格查询 - 关键！这里要返回"有试用资格"
            return createTrialEligibilityResponse()
        } else if url.contains("/v1/subscriptions/") {
            // 订阅状态查询 - 返回"有效订阅"
            return createActiveSubscriptionResponse()
        } else if url.contains("/v1/transactions/") {
            // 交易查询 - 返回"已购买"
            return createPurchasedTransactionResponse()
        } else {
            // 其他 StoreKit 2 请求
            return createStoreKit2Response()
        }
    }
    
    private static func createStoreKit2Response() -> Data? {
        let response: [String: Any] = [
            "signedTransactionInfo": createFakeJWS(),
            "status": 0,
            "environment": "Production",
            "bundleId": Bundle.main.bundleIdentifier ?? ""
        ]
        return try? JSONSerialization.data(withJSONObject: response)
    }
    
    // 创建试用资格响应 - 关键函数！
    private static func createTrialEligibilityResponse() -> Data? {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.unknown.app"
        let response: [String: Any] = [
            "data": [
                [
                    "subscriptionGroupIdentifier": generateSubscriptionGroupId(from: bundleId),
                    "productId": "\(bundleId).premium",
                    "eligible": true,  // 关键：有试用资格
                    "ineligibleReasons": []
                ]
            ],
            "status": 0,
            "environment": "Production"
        ]
        print("[SatellaJailed] 返回试用资格响应: 有资格")
        return try? JSONSerialization.data(withJSONObject: response)
    }
    
    // 创建有效订阅响应
    private static func createActiveSubscriptionResponse() -> Data? {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.unknown.app"
        let currentTime = Int(Date().timeIntervalSince1970 * 1000)
        let expirationTime = Int(Date().addingTimeInterval(365*24*3600).timeIntervalSince1970 * 1000)
        
        let response: [String: Any] = [
            "data": [
                [
                    "subscriptionGroupIdentifier": generateSubscriptionGroupId(from: bundleId),
                    "productId": "\(bundleId).premium",
                    "subscriptionState": "ACTIVE",  // 有效订阅
                    "expiresDate": expirationTime,
                    "purchaseDate": currentTime,
                    "originalTransactionId": "fake_original_\(UUID().uuidString)",
                    "transactionId": "fake_transaction_\(UUID().uuidString)",
                    "inAppOwnershipType": "PURCHASED",
                    "autoRenewStatus": 1,
                    "environment": "Production"
                ]
            ],
            "status": 0,
            "environment": "Production"
        ]
        print("[SatellaJailed] 返回有效订阅响应")
        return try? JSONSerialization.data(withJSONObject: response)
    }
    
    // 创建已购买交易响应
    private static func createPurchasedTransactionResponse() -> Data? {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.unknown.app"
        let currentTime = Int(Date().timeIntervalSince1970 * 1000)
        let expirationTime = Int(Date().addingTimeInterval(365*24*3600).timeIntervalSince1970 * 1000)
        
        let response: [String: Any] = [
            "data": [
                [
                    "productId": "\(bundleId).premium",
                    "transactionId": "fake_transaction_\(UUID().uuidString)",
                    "originalTransactionId": "fake_original_\(UUID().uuidString)",
                    "purchaseDate": currentTime,
                    "expiresDate": expirationTime,
                    "inAppOwnershipType": "PURCHASED",
                    "subscriptionGroupIdentifier": generateSubscriptionGroupId(from: bundleId),
                    "environment": "Production",
                    "storefront": "USA",
                    "storefrontId": "143441"
                ]
            ],
            "status": 0,
            "environment": "Production"
        ]
        print("[SatellaJailed] 返回已购买交易响应")
        return try? JSONSerialization.data(withJSONObject: response)
    }
    
    private static func createFakeJWS() -> String {
        // 创建假的 JWS 签名
        let header = ["alg": "ES256", "kid": "ABCDEF1234"]
        
        // 动态获取产品ID
        let bundleId = Bundle.main.bundleIdentifier ?? "com.unknown.app"
        let productId = "\(bundleId).premium"
        
        let payload = [
            "productId": productId,
            "originalTransactionId": "1000000000000000",
            "transactionId": "1000000000000001", 
            "purchaseDate": 1640995200000,
            "expiresDate": 4092599349000, // 2099年
            "inAppOwnershipType": "PURCHASED",
            "subscriptionGroupIdentifier": generateSubscriptionGroupId(from: bundleId)
        ] as [String: Any]
        
        return encodeJWS(header: header, payload: payload)
    }
    
    private static func generateSubscriptionGroupId(from bundleId: String) -> String {
        let hash = abs(bundleId.hashValue)
        return String(format: "%010d", hash % 10000000000)
    }
    
    private static func encodeJWS(header: [String: Any], payload: [String: Any]) -> String {
        let headerData = try! JSONSerialization.data(withJSONObject: header)
        let payloadData = try! JSONSerialization.data(withJSONObject: payload)
        
        let headerB64 = headerData.base64EncodedString()
        let payloadB64 = payloadData.base64EncodedString()
        let signature = "fake_signature_data"
        
        return "\(headerB64).\(payloadB64).\(signature)"
    }
}
