import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var keywordDraft = ""
    @State private var keywordError: String?
    @FocusState private var isKeywordInputFocused: Bool

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

            if model.isCapturing || model.monitoringIssue != nil {
                Button("중지") {
                    model.stopCapture()
                }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(model.isChangingCapture)
            }

            if !model.isCapturing {
                Button("캡처 시작") {
                    model.startCapture()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.selectedWindowID == nil || model.isChangingCapture)
            }
        }
    }

    private var targetControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("탐지 키워드 \(model.keywordMonitor.keywords.count)개")
                    .font(.headline)
                Text("하나라도 포함되면 알림 · 개수 제한 없이 추가")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 14) {
                TextField("키워드 입력 후 Enter (예: 작업 완료)", text: $keywordDraft)
                    .textFieldStyle(.roundedBorder)
                    .focused($isKeywordInputFocused)
                    .onSubmit {
                        addKeyword()
                    }
                    .onChange(of: keywordDraft) { _, _ in
                        keywordError = nil
                    }
                    .accessibilityLabel("추가할 탐지 키워드")

                Button("추가", systemImage: "plus") {
                    addKeyword()
                }
                .disabled(keywordDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack(spacing: 14) {
                Toggle("대소문자 구분", isOn: $model.caseSensitive)
                    .toggleStyle(.checkbox)

                Toggle("띄어쓰기 무시", isOn: $model.ignoreWhitespace)
                    .toggleStyle(.checkbox)
                    .help("공백·줄바꿈·탭을 무시하여 ‘낚시금지’로 ‘낚시 금지’도 탐지합니다.")

                Stepper(
                    "재알림 \(Int(model.cooldownSeconds))초",
                    value: $model.cooldownSeconds,
                    in: 0...60,
                    step: 1
                )
                .frame(width: 130)

                Spacer()

                Text("키워드·설정 자동 저장")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("영역 초기화") {
                    model.resetRegion()
                }
            }

            if let keywordError {
                Text(keywordError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if model.keywordMonitor.keywords.isEmpty {
                Text("탐지할 키워드를 추가하세요. 단어와 문장을 모두 등록할 수 있습니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(model.keywordMonitor.keywords, id: \.self) { keyword in
                            keywordRow(keyword)
                        }
                    }
                    .padding(8)
                }
                .frame(height: min(CGFloat(model.keywordMonitor.keywords.count) * 36 + 10, 118))
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func keywordRow(_ keyword: String) -> some View {
        HStack(spacing: 8) {
            Text(keyword)
                .lineLimit(1)
                .help(keyword)
            Spacer()
            if model.isTargetDetected && model.keywordMonitor.matchedKeywords.contains(keyword) {
                Label("감지됨", systemImage: "bell.badge.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            Button {
                model.removeKeyword(keyword)
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("키워드 삭제: \(keyword)")
            .accessibilityLabel("키워드 삭제: \(keyword)")
        }
        .frame(minHeight: 30)
    }

    private func addKeyword() {
        if model.addKeyword(keywordDraft) {
            keywordDraft = ""
            keywordError = nil
        } else {
            keywordError = "빈 키워드나 이미 등록된 키워드는 추가할 수 없습니다."
        }
        isKeywordInputFocused = true
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
