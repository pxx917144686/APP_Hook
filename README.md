<div style="text-align: center; font-family: 'Arial', sans-serif; color: #e63946; padding: 20px;">
  <h1 style="font-size: 36px; font-weight: bold; margin: 10px 0; text-shadow: 2px 2px 4px rgba(0,0,0,0.2);">
    未完待续！非最终版！
  </h1>
  <h1 style="font-size: 32px; font-weight: bold; color: #1d3557; margin: 10px 0; text-shadow: 2px 2px 4px rgba(0,0,0,0.2);">
  To Be Continued! Not the Final Version!
  </h1>
</div>

<img width="1154" height="888" alt="x" src="https://github.com/user-attachments/assets/736cb247-cc0a-4176-a93b-187d625a8a5b" />

## 内容解释

### 核心入口
- `Tweak.swift` - 主入口点和初始化
- `Hook.swift` - Hook 基础协议定义
- `HookFunc.swift` - 函数 Hook 协议
- `HookGroup.swift` - Hook 组协议

### StoreKit 1 Hook 模块
- `CanPayHook.swift` - 支付能力检测 Hook
- `DelegateHook.swift` - SKProductsRequest 代理 Hook
- `TransactionHook.swift` - 支付状态和交易 Hook
- `ProductHook.swift` - APP价格 Hook (显示 0.00 价格)
- `ObserverHook.swift` - 支付观察者 Hook
- `ReceiptHook.swift` - 收据验证 Hook

### StoreKit 2 Hook 模块 (iOS 15.0+)
- `StoreKit2Hook.swift` - StoreKit2 Hook
  - Transaction.currentEntitlements Hook
  - Transaction.updates Hook  
  - Product.purchase Hook
  - VerificationResult Hook
  - AppStore.requestReceipt Hook
- `StoreKit2StorageHook.swift` - StoreKit 2 存储层 Hook
  - SQLite 数据库操作拦截
  - StoreKit 本地存储伪造
  - 收据存储管理
  - PAC 指针保护处理
- `StoreKit2EntitlementHook.swift` - StoreKit 2 权益管理 Hook
  - 订阅权益伪造
  - 验证结果篡改
  - 续费信息模拟

### 系统级 Hook
- `DyldHook.swift` - 动态库名伪装 Hook
- `URLHook.swift` - 网络验证拦截 Hook
  - Apple 官方验证端点拦截
  - 第三方验证服务拦截
  - 收据验证请求伪造

### 重绑定工具
- `RebindHook.swift` - 符号重绑定 Hook
- `Rebind.swift` - 底层重绑定工具
  - 动态符号解析
  - 函数指针替换
  - ARM64 指令修补

### 数据模型
- `Receipt.swift` - 现代收据数据结构
- `ReceiptInfo.swift` - 收据详细信息
- `ReceiptResponse.swift` - 收据验证响应
- `OldReceipt.swift` - 旧版 StoreKit 收据
- `OldReceiptInfo.swift` - 旧版收据信息

### 服务组件
- `Delegate.swift` - SatellaDelegate APP 请求代理
- `Observer.swift` - SatellaObserver 支付交易监听
- `ReceiptGenerator.swift` - 动态收据生成器
  - 假收据数据
  - 签名模拟
  - 过期时间

### 用户界面
- `SatellaView.swift` - 主控制界面
- `PreferencesView.swift` - 高级设置界面
- `PassthroughView.swift` - 透明视图组件

### 配置管理
- `Preferences.swift` - 用户偏好设置
- `JinxPreferences.swift` - 配置文件读取
  - Hook 总开关
  - APP 产品 ID 配置
  - 选项

### 辅助工具
- `BindableGesture.swift` - 手势绑定工具
- `Lock.swift` - 线程安全锁机制
- `Ivar.swift` - 运行时变量操作
- `load.s` - ARM64 汇编加载器

### 编译解释
- `Package.swift` - Swift 包管理配置
- `Makefile` - Theos 编译
- `control` - Deb 包控制文件



## 编译
- `make clean && make package`
