import Foundation

extension Notification.Name {
    /// App a Reu Impress custom notification
    static let appDidEnterBackground = Notification.Name("appDidEnterBackgroundNotification")
    /// 壁纸设置发生变化的通知
    static let wallpaperSettingsChanged = Notification.Name("wallpaperSettingsChanged")
    /// 聊天会话选择的通知
    static let didSelectChatSession = Notification.Name("didSelectChatSession")
    static let didDeleteChatSession = Notification.Name("didDeleteChatSession")
    static let didUpdateChatSession = Notification.Name("didUpdateChatSession")
    /// 预设聊天列表数据更新的通知
    static let didUpdatePreChatList = Notification.Name("didUpdatePreChatList")
}
