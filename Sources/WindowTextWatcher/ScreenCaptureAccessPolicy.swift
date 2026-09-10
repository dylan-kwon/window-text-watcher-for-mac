struct ScreenCaptureAccessPolicy {
    static let permissionRequiredMessage = "화면 기록 권한이 필요합니다. 권한을 허용한 뒤 창 목록을 다시 불러오세요."

    static func canLoadWindows(
        hasPermission: Bool
    ) -> Bool {
        _ = hasPermission
        return true
    }
}
