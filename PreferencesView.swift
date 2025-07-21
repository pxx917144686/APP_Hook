import SwiftUI
import Foundation

@available(iOS 15, *)
struct PreferencesView: View {
    @AppStorage("tella_isEnabled") private var isEnabled: Bool = true
    @AppStorage("tella_isGesture") private var isGesture: Bool = true
    @AppStorage("tella_isHidden") private var isHidden: Bool = false
    @AppStorage("tella_isObserver") private var isObserver: Bool = false
    @AppStorage("tella_isPriceZero") private var isPriceZero: Bool = false
    @AppStorage("tella_isReceipt") private var isReceipt: Bool = false
    @AppStorage("tella_isStealth") private var isStealth: Bool = false
    
    @Binding var isShowing: Bool
    @State private var showResetConfirmation = false
    @State private var showRestartRequired = false

    private func onSettingChanged() {
        // 只显示重启提示，不执行操作
        showRestartRequired = true
    }
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // 图标
                    HStack {
                        Spacer()
                        Color(red: 0.80, green: 0.63, blue: 0.87)
                            .mask { SatellaShapeView() }
                            .frame(width: 50, height: 50)
                        Spacer()
                    }
                    .padding()

                    // 功能开关
                    GroupBox(label: Label("功能开关", systemImage: "gear")) {
                        VStack(alignment: .leading, spacing: 12) {
                            ToggleWithDescription(
                                isOn: $isEnabled,
                                title: "总开关",
                                description: "开启或关闭所有功能",
                                onChange: onSettingChanged
                            )
                            
                            Divider()
                            
                            ToggleWithDescription(
                                isOn: $isGesture,
                                title: "三指轻点打开设置",
                                description: "使用三指轻点手势打开设置面板",
                                onChange: onSettingChanged,
                                dependsOn: $isEnabled
                            )
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                    
                    // 显示选项
                    GroupBox(label: Label("显示选项", systemImage: "eye")) {
                        VStack(alignment: .leading, spacing: 12) {
                            ToggleWithDescription(
                                isOn: $isObserver,
                                title: "显示悬浮图标",
                                description: "在屏幕上显示可拖动的悬浮窗图标",
                                onChange: onSettingChanged,
                                dependsOn: $isEnabled
                            )
                            
                            Divider()
                            
                            ToggleWithDescription(
                                isOn: $isStealth,
                                title: "隐藏",
                                description: "隐藏图标和通知",
                                onChange: onSettingChanged,
                                dependsOn: $isEnabled
                            )
                            
                            Divider()
                            
                            ToggleWithDescription(
                                isOn: $isHidden,
                                title: "永久隐藏",
                                description: "完全隐藏悬浮窗图标",
                                onChange: onSettingChanged,
                                dependsOn: $isEnabled
                            )
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                    
                    // 高级功能
                    GroupBox(label: Label("高级功能", systemImage: "wand.and.stars")) {
                        VStack(alignment: .leading, spacing: 12) {
                            ToggleWithDescription(
                                isOn: $isPriceZero,
                                title: "价格显示为 0,00",
                                description: "将APP内价格显示修改为0,00",
                                onChange: onSettingChanged,
                                dependsOn: $isEnabled
                            )
                            
                            Divider()
                            
                            ToggleWithDescription(
                                isOn: $isReceipt,
                                title: "收据功能",
                                description: "启用收据相关功能",
                                onChange: onSettingChanged,
                                dependsOn: $isEnabled
                            )
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                    
                    // 操作按钮
                    VStack(spacing: 16) {
                        Button("重置所有设置") {
                            showResetConfirmation = true
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red, lineWidth: 1)
                        )

                        Button("👉看看源代码") {
                            UIApplication.shared.open(
                                URL(string: "https://github.com/pxx917144686/SatellaJailed")!,
                                options: [:],
                                completionHandler: nil
                            )
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("")
            .navigationBarHidden(true) // 完全隐藏导航栏
            .overlay(
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            isShowing.toggle()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    Spacer()
                },
                alignment: .topTrailing
            )
            .alert("确认重置", isPresented: $showResetConfirmation) {
                Button("取消", role: .cancel) { }
                Button("重置", role: .destructive) {
                    // 重置所有设置
                    isEnabled = true
                    isGesture = true
                    isHidden = false
                    isObserver = false
                    isPriceZero = false
                    isReceipt = false
                    isStealth = false
                    showRestartRequired = true
                }
            } message: {
                Text("将所有设置恢复为默认值？")
            }
            .alert("需要重启APP", isPresented: $showRestartRequired) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("设置已保存，重启APP，更改生效")
            }
        }
        .tint(Color(red: 0.80, green: 0.63, blue: 0.87))
    }
}

// 带描述的Toggle组件
struct ToggleWithDescription: View {
    @Binding var isOn: Bool
    var title: String
    var description: String
    var onChange: () -> Void
    var dependsOn: Binding<Bool>? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: Binding(
                get: { 
                    // 如果有依赖且依赖为false，则此项也为false
                    if let depends = dependsOn, !depends.wrappedValue {
                        return false
                    }
                    return isOn 
                },
                set: { newValue in
                    // 如果有依赖且依赖为false，则不允许修改
                    if let depends = dependsOn, !depends.wrappedValue {
                        return
                    }
                    isOn = newValue
                    onChange()
                }
            )) {
                Text(title)
                    .fontWeight(.medium)
                    .foregroundColor(
                        (dependsOn != nil && !dependsOn!.wrappedValue) ? .secondary : .primary
                    )
            }
            .disabled(dependsOn != nil && !dependsOn!.wrappedValue)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
        }
    }
}
