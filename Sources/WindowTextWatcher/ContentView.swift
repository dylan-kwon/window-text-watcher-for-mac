import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 14) {
            header
            if let issue = model.monitoringIssue {
                Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            captureControls
            targetControls
            previewAndResult
        }
        .padding(16)
        .frame(minWidth: 940, minHeight: 680)
        .task {
            model.refreshWindows()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                model.refreshWindowsIfAuthorized()
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Window Text Watcher")
                    .font(.title2.bold())
                Text(model.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label(
                model.monitoringIssue != nil ? "감시 이상" : (model.isCapturing ? "실시간 캡처 중" : "중지됨"),
                systemImage: model.isCapturing ? "record.circle" : "stop.circle"
            )
            .foregroundStyle(model.monitoringIssue != nil ? .orange : (model.isCapturing ? .green : .secondary))

            Text(model.notificationStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("테스트 알림") {
                model.sendTestNotification()
            }

            if model.needsScreenRecordingPermission {
                Button("화면 기록 권한 요청") {
                    model.requestScreenRecordingPermission()
                }
                .buttonStyle(.borderedProminent)

                Button("화면 기록 권한 열기") {
                    model.openScreenRecordingSettings()
                }
            }
        }
    }

    private var captureControls: some View {
        HStack(spacing: 10) {
            Picker("캡처 창", selection: $model.selectedWindowID) {
                Text("창 선택…")
                    .tag(Optional<CGWindowID>.none)

                ForEach(model.windows) { window in
                    Text(window.displayName)
                        .tag(Optional(window.id))
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .disabled(model.needsScreenRecordingPermission || model.isCapturing || model.isChangingCapture)

            Button("새로고침") {
                model.refreshWindows()
            }

            if model.isCapturing {
                Button("중지") {
                    model.stopCapture()
                }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(model.isChangingCapture)
            } else {
                Button("캡처 시작") {
                    model.startCapture()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.selectedWindowID == nil || model.isChangingCapture)
            }
        }
    }

    private var targetControls: some View {
        HStack(spacing: 14) {
            TextField("감지할 텍스트 (예: 작업이 완료되었습니다)", text: $model.targetText)
                .textFieldStyle(.roundedBorder)

            Toggle("대소문자 구분", isOn: $model.caseSensitive)
                .toggleStyle(.checkbox)

            Stepper(
                "재알림 \(Int(model.cooldownSeconds))초",
                value: $model.cooldownSeconds,
                in: 0...60,
                step: 1
            )
            .frame(width: 130)

            Button("영역 초기화") {
                model.resetRegion()
            }
        }
    }

    private var previewAndResult: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("미리보기 / OCR 영역")
                        .font(.headline)
                    Spacer()
                    Text("마우스로 드래그하여 영역 선택")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                CapturePreview(
                    image: model.latestFrame,
                    region: $model.region
                )
            }
            .frame(minWidth: 580)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("OCR 결과")
                        .font(.headline)
                    Spacer()
                    if model.isTargetDetected {
                        Label("감지됨", systemImage: "bell.badge.fill")
                            .foregroundStyle(.green)
                    }
                }

                ScrollView {
                    Text(model.recognizedText.isEmpty ? "아직 인식된 텍스트가 없습니다." : model.recognizedText)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(10)
                }
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("OCR 주기: 약 0.45초 · 감지 중에는 재알림 설정 시간마다 반복 알림")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 280)
        }
    }
}
