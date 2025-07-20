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

### 核心组件
- `Tweak.swift` - 主入口
- `Hook.swift` - Hook 基础协议定义
- `HookFunc.swift` - 函数 Hook 协议
- `HookGroup.swift` - Hook 组协议

### 主要 Hook
- `CanPayHook.swift` - 支付检测 Hook
- `DelegateHook.swift` - SKProductsRequest 代理 Hook
- `TransactionHook.swift` - 支付状态 Hook
- `ProductHook.swift` - 价格 Hook (0.00 价格)
- `ObserverHook.swift` - 支付检查 Hook
- `DyldHook.swift` - 动态库名伪装 Hook
- `ReceiptHook.swift` - 收据验证 Hook
- `RebindHook.swift` - 重绑定 Hook
- `URLHook.swift` - 网络验证拦截 Hook (支持 Apple 官方和第三方验证端点)
  - `/itunesreceipt`
  - `/validateReceipt`
  - `/users/validate`

### 数据模版
- `Receipt.swift` - 收据数据结构
- `ReceiptInfo.swift` - 收据信息
- `ReceiptResponse.swift` - 收据响应
- `OldReceipt.swift` - 旧版收据
- `OldReceiptInfo.swift` - 旧版收据信息

### 服务类
- `Delegate.swift` - SatellaDelegate APP 请求代理
- `Observer.swift` - SatellaObserver 支付交易检测
- `ReceiptGenerator.swift` - 收据生成器

### UI 界面
- `SatellaView.swift` - SatellaView 主界面
- `PreferencesView.swift` - 设置界面
- `PassthroughView.swift` - 视图

### 设置和工具
- `Preferences.swift` - 偏好设置
- `JinxPreferences.swift` - 配置读取
- `BindableGesture.swift` - 手势绑定
- `Lock.swift` - 锁机制
- `Ivar.swift` - 变量操作
- `Rebind.swift` - 重绑定工具



## 编译
- `make clean && make package`
