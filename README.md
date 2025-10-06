# QishuiVIPAuto

一个自动领取汽水音乐畅听权益的越狱插件。

## ✨ 功能
- 每日自动检测是否已领取会员。
- 未领取则自动调用 API 进行领取。
- 使用 LunaToast 显示成功或失败提示。

## 🧩 兼容
- 支持 iOS 14 ~ 17
- 支持 SchubertApp（汽水音乐）

## 📦 编译与安装
```bash
make package
make install
```

## ⚙️ 环境要求
- 已安装 Theos，并正确设置 `THEOS` 环境变量
- 设备为越狱 iOS（iOS 14 ~ 17），并安装 `mobilesubstrate`
- 目标 App：`SchubertApp`（汽水音乐），Bundle 过滤在 `QishuiVIPAuto.plist`

## 🔧 实现说明
- 通过监听 `UIApplicationDidBecomeActiveNotification` 在应用进入前台时触发检测
- 每日仅触发一次：使用 `NSUserDefaults` 记录 `LastIncentiveRequestDate`
- 互斥与去抖：使用 `NSLock` 和会话内布尔标记规避重复触发
- 使用外部 `LunaUtils` 请求 API，并通过 `LunaToast` 反馈结果

## 📝 变更
- 使用通知替换原先的 `AppDelegate` 方法 Hook，兼容性更好
- 抽取公共检测/调度函数，强化健壮性与日志
