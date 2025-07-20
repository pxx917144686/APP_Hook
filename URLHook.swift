import Foundation

struct URLHook: Hook {
    typealias URLHandler = @Sendable (Data?, URLResponse?, Error?) -> Void
    typealias T = @convention(c) (URLSession, Selector, URLRequest, @escaping (URLHandler)) -> URLSessionDataTask

    let cls: AnyClass? = URLSession.self
    let sel: Selector = sel_registerName("dataTaskWithRequest:completionHandler:")
    
    // 处理规则
    static var appRules: [String: AppRule] = [:]

    // 扩展第三方验证
    static var interceptPatterns: [String] = [
        "/verifyReceipt",          // Apple官方
        "/itunesreceipt",          // 通用iTunes收据验证
        "/receipt/verify",         // 常见的收据验证路径
        "/api/verify",             // API验证端点
        "/subscription/check",     // 订阅检查端点
        "/validateReceipt",        // 第三方验证端点
        "/users/validate",         // 用户验证端点
        "/v1/users/",              // 版本化API
        "/premium/check",          // 高级版检查
        "/license/verify"          // 许可证验证
    ]
    
    let replace: T = { obj, sel, request, handler in
        guard let url = request.url?.absoluteString else {
            return orig(obj, sel, request, handler)
        }
        
        let shouldIntercept = URLHook.interceptPatterns.contains { pattern in
            url.contains(pattern)
        }
        
        if shouldIntercept {
            let newHandler: URLHandler = { (originalData, response, error) in
                let fakeData = URLHook.generateIntelligentResponse(
                    request: request,
                    originalData: originalData
                )
                handler(fakeData, response, error)
            }
            
            return orig(obj, sel, request, newHandler)
        }

        return orig(obj, sel, request, handler)
    }
    
    // 响应生成
    private static func generateIntelligentResponse(request: URLRequest, originalData: Data?) -> Data? {
        // 获取bundle_id和UA信息
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let userAgent = request.value(forHTTPHeaderField: "User-Agent") ?? ""
        let url = request.url?.absoluteString ?? ""
        
        // 解析原始响应
        var responseData: [String: Any] = [:]
        if let data = originalData,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            responseData = json
        }
        
        // 判断验证类型
        if isThirdPartyValidation(url: url) {
            return generateThirdPartyResponse(url: url, bundleId: bundleId, responseData: responseData)
        }
        
        // 原有的Apple Store验证逻辑
        let matchedRule = findMatchingRule(bundleId: bundleId, userAgent: userAgent)
        
        if let rule = matchedRule {
            return processWithRule(rule: rule, bundleId: bundleId, responseData: responseData)
        } else {
            return generateFallbackResponse(bundleId: bundleId, responseData: responseData)
        }
    }
    
    // 判断是否为第三方验证
    private static func isThirdPartyValidation(url: String) -> Bool {
        let thirdPartyPatterns = [
            "duetdisplay.com",
            "validateReceipt",
            "/users/validate",
            "/premium/check",
            "/license/verify"
        ]
        
        return thirdPartyPatterns.contains { pattern in
            url.contains(pattern)
        }
    }
    
    // 生成第三方验证响应
    private static func generateThirdPartyResponse(url: String, bundleId: String, responseData: [String: Any]) -> Data? {
        // 根据URL特征生成不同格式的响应
        
        if url.contains("duetdisplay.com") {
            // DuetDisplay特定响应
            let duetResponse: [String: Any] = [
                "success": true,
                "products": [[
                    "vendor": "apple",
                    "product": "DuetAirAnnual",
                    "subscriptionId": 391961,
                    "purchaseDate": "2023-11-14T19:47:25Z",
                    "cancelled": false,
                    "expiresDate": "2099-11-09T19:47:22Z",
                    "inTrial": true
                ]],
                "hasStripeAccount": false
            ]
            return try? JSONSerialization.data(withJSONObject: duetResponse)
        }
        
        // 通用第三方成功响应
        var response = responseData
        if response.isEmpty {
            response = [:]
        }
        
        // 通用成功字段
        response["success"] = true
        response["status"] = "active"
        response["premium"] = true
        response["subscribed"] = true
        response["valid"] = true
        response["expires"] = "2099-12-31T23:59:59Z"
        response["trial"] = true
        response["pro"] = true
        
        // 如果原响应有特定字段，保持其结构但修改值
        if response["data"] != nil {
            var data = response["data"] as? [String: Any] ?? [:]
            data["premium"] = true
            data["valid"] = true
            response["data"] = data
        }
        
        if response["user"] != nil {
            var user = response["user"] as? [String: Any] ?? [:]
            user["premium"] = true
            user["subscribed"] = true
            response["user"] = user
        }
        
        return try? JSONSerialization.data(withJSONObject: response)
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
}
