<div style="text-align: center; font-family: 'Arial', sans-serif; color: #e63946; padding: 20px;">
  <h1 style="font-size: 36px; font-weight: bold; margin: 10px 0; text-shadow: 2px 2px 4px rgba(0,0,0,0.2);">
    未完待续！非最终版！
  </h1>
  <h1 style="font-size: 32px; font-weight: bold; color: #1d3557; margin: 10px 0; text-shadow: 2px 2px 4px rgba(0,0,0,0.2);">
  To Be Continued! Not the Final Version!
  </h1>
</div>

<img width="1154" height="888" alt="x" src="https://github.com/user-attachments/assets/736cb247-cc0a-4176-a93b-187d625a8a5b" />



## 项目结构

### 核心入口
- `Tweak.swift` - 主入口点和初始化

### Core/ - 核心运行时框架
- `DyldHook.swift` - 动态库名伪装 Hook
- `JinxCompat.swift` - Jinx 框架兼容层

### Jinx/ - Jinx Hook 框架 (已集成)
- `Package.swift` - Swift 包管理配置
- `Sources/Jinx/` - Jinx 框架源码
  - `Core/` - 核心功能
    - `Rebind.swift` - 底层重绑定工具
    - `Replace.swift` - 方法替换实现
    - `Substrate.swift` - Substrate 兼容层
  - `Protocols/` - 协议定义
    - `Hook.swift` - Hook 基础协议定义
    - `HookFunc.swift` - 函数 Hook 协议
    - `HookGroup.swift` - Hook 组协议
  - `Types/` - 类型定义
    - `RebindHook.swift` - 符号重绑定 Hook
    - `Table.swift` - 符号表处理
  - `Helpers/` - 辅助工具
    - `Ivar.swift` - 运行时变量操作
    - `JinxPreferences.swift` - 配置文件读取
    - `Lock.swift` - 线程安全锁机制
    - `Storage.swift` - 运行时存储管理
  - `Extensions/` - 扩展功能
    - `String.swift` - 字符串扩展工具

### Sk1/ - StoreKit 1 Hook 模块
- `Sk1Hooks.swift` - SK1 Hook 统一入口
- `CanPayHook.swift` - 支付能力检测 Hook
- `DelegateHook.swift` - SKProductsRequest 代理 Hook
- `TransactionHook.swift` - 支付状态和交易 Hook
- `ProductHook.swift` - APP价格 Hook (显示 0.00 价格)
- `ObserverHook.swift` - 支付观察者 Hook
- `ReceiptHook.swift` - 收据验证 Hook
- `Delegate.swift` - SatellaDelegate APP 请求代理
- `Observer.swift` - SatellaObserver 支付交易监听

### Sk2/ - StoreKit 2 Hook 模块 (iOS 15.0+)
- `Sk2Hooks.swift` - SK2 Hook 统一入口
- `URLHook.swift` - 网络验证拦截 Hook
  - Apple 官方验证端点拦截
  - StoreKit 2 App Store Server API 拦截
  - 第三方验证服务拦截
  - 智能 API 类型识别和处理
    - 订阅状态 API 处理
    - 用户信息 API 处理
    - 收据验证 API 处理
    - VIP 状态 API 处理
    - GraphQL API 处理
  - 应用类型分类处理
    - 音频应用处理
    - 生产力应用处理
    - 教育应用处理
  - 收据验证请求伪造

### UI/ - 用户界面模块
- `SatellaView.swift` - 主控制界面
- `PreferencesView.swift` - 高级设置界面
- `SatellaController.swift` - 视图控制器
- `PassthroughView.swift` - 透明视图组件
- `SatellaShape.swift` - 自定义形状绘制
- `BindableGesture.swift` - 手势绑定工具
- `UIViewController.swift` - 视图控制器扩展
- `WindowHook.swift` - 窗口 Hook

### Models/ - 数据模型与配置
- `Preferences.swift` - 用户偏好设置
- `SatellaModel.swift` - 数据模型
- `Receipt.swift` - 现代收据数据结构
- `ReceiptInfo.swift` - 收据详细信息
- `ReceiptResponse.swift` - 收据验证响应
- `OldReceipt.swift` - 旧版 StoreKit 收据
- `OldReceiptInfo.swift` - 旧版收据信息
- `RenewalInfo.swift` - 续费信息模型
- `ReceiptGenerator.swift` - 动态收据生成器

### 编译配置
- `Package.swift` - Swift 包管理配置
- `Makefile` - Theos 编译配置
- `control` - Deb 包控制文件
- `load.s` - ARM64 汇编加载器



## 编译

### 编译步骤
```bash
# 进入项目目录
cd APP_Hook

# 清理并编译
make clean && make package

```
