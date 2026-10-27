//
//  IslandWalkerApp.swift
//  Target: IslandWalker (iPhone 主程式 · 可在 App 內隨時切換「📍原地站著不動」與「🚶左右散步」)
//

import SwiftUI
import ActivityKit
import AVFoundation

@main
struct IslandWalkerApp: App {
    var body: some Scene {
        WindowGroup {
            WalkerConsoleView()
                .preferredColorScheme(.dark)
        }
    }
}

@MainActor
final class IslandWalkerController: ObservableObject {
    @Published var isIslandActive: Bool = false
    @Published var isStationary: Bool = true
    @Published var isEcoMode: Bool = false
    @Published var stepIndex: Int = 0
    @Published var positionX: Double = 44.0
    @Published var facingLeft: Bool = false
    @Published var bubbleText: String = PetDialogueBank.autoLines.first ?? "在動態島陪妳 ♪"
    @Published var statusLog: String = "READY · 可切換「原地站著不動」或「左右散步」"

    private var timer: Timer?
    private var bubbleHideTask: Task<Void, Never>?
    private var audioPlayer: AVAudioPlayer?
    private var stepsSinceLastBubble: Int = 0
    private var nextRandomBubbleStepTarget: Int = 18
    private let patrolLimit: Double = 56.0
    private let stationaryAnchorX: Double = 44.0
    private let totalFrames: Int = 5

    func pokePet() {
        let newLine = PetDialogueBank.pickRandomPokeLine(excluding: bubbleText)
        showTemporaryBubble(newLine, durationSeconds: 4.0)
        pushStateToIsland()
    }

    func toggleStationaryMode() {
        isStationary.toggle()
        if isStationary {
            positionX = stationaryAnchorX
        }
        pushStateToIsland()
    }

    func showTemporaryBubble(_ text: String, durationSeconds: Double) {
        bubbleText = text
        bubbleHideTask?.cancel()
        bubbleHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(durationSeconds * 1_000_000_000))
            if !Task.isCancelled {
                self.bubbleText = ""
                self.pushStateToIsland()
            }
        }
    }

    func startIslandWalk() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            statusLog = "請至 iPhone「設定 > 允許即時動態」開啟權限"
            return
        }

        stopIslandWalk()

        if !isEcoMode {
            startSilentAudioKeepAlive()
        }

        if isStationary {
            positionX = stationaryAnchorX
        }

        let attr = IslandWalkerAttributes(petName: "池鷗")
        let initialState = IslandWalkerAttributes.ContentState(
            stepIndex: 0,
            positionX: positionX,
            facingLeft: facingLeft,
            isStationary: isStationary,
            isEcoMode: isEcoMode,
            bubbleText: bubbleText
        )

        do {
            _ = try Activity.request(
                attributes: attr,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            isIslandActive = true
            statusLog = isStationary
                ? "已上島 (📍 原地定點模式) · 點擊可戳出隨機台詞"
                : "已上島 (🚶 左右散步模式) · 點擊可戳出隨機台詞"
            startStepLoop()
        } catch {
            statusLog = "啟動失敗: \(error.localizedDescription)"
        }
    }

    func stopIslandWalk() {
        timer?.invalidate()
        timer = nil
        audioPlayer?.stop()
        Task {
            for activity in Activity<IslandWalkerAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        isIslandActive = false
        statusLog = "已從動態島召回休息"
    }

    func toggleEngineMode() {
        isEcoMode.toggle()
        if isIslandActive {
            startIslandWalk()
        }
    }

    private func startStepLoop() {
        let interval = isEcoMode ? 1.0 : 0.38
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceOneStep()
            }
        }
    }

    private func advanceOneStep() {
        stepIndex = (stepIndex + 1) % max(1, totalFrames)

        if isStationary {
            // 📍 原地站著不動：鎖定在指定座標，只播原地動作幀，絕不左右亂跑
            positionX = stationaryAnchorX
        } else {
            // 🚶 左右來回散步
            let delta: Double = facingLeft ? -6.0 : 6.0
            var nextX = positionX + delta

            if nextX >= patrolLimit {
                nextX = patrolLimit
                facingLeft = true
            } else if nextX <= -patrolLimit {
                nextX = -patrolLimit
                facingLeft = false
            }
            positionX = nextX
        }

        // 不定時隨機冒出泡泡框邏輯
        stepsSinceLastBubble += 1
        if stepsSinceLastBubble >= nextRandomBubbleStepTarget {
            stepsSinceLastBubble = 0
            nextRandomBubbleStepTarget = Int.random(in: 14...32)
            let randomAutoLine = PetDialogueBank.pickRandomAutoLine(excluding: bubbleText)
            showTemporaryBubble(randomAutoLine, durationSeconds: 4.0)
        }

        pushStateToIsland()
    }

    private func pushStateToIsland() {
        let updatedState = IslandWalkerAttributes.ContentState(
            stepIndex: stepIndex,
            positionX: positionX,
            facingLeft: facingLeft,
            isStationary: isStationary,
            isEcoMode: isEcoMode,
            bubbleText: bubbleText
        )

        Task {
            for activity in Activity<IslandWalkerAttributes>.activities {
                await activity.update(.init(state: updatedState, staleDate: nil))
            }
        }
    }

    private func startSilentAudioKeepAlive() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)

            let sampleRate: UInt32 = 8000
            let numSamples: UInt32 = 8000
            var wavData = Data()
            let totalDataLen = numSamples + 36
            let byteRate = sampleRate

            wavData.append("RIFF".data(using: .ascii)!)
            withUnsafeBytes(of: totalDataLen.littleEndian) { wavData.append(contentsOf: $0) }
            wavData.append("WAVEfmt ".data(using: .ascii)!)
            withUnsafeBytes(of: UInt32(16).littleEndian) { wavData.append(contentsOf: $0) }
            withUnsafeBytes(of: UInt16(1).littleEndian) { wavData.append(contentsOf: $0) }
            withUnsafeBytes(of: UInt16(1).littleEndian) { wavData.append(contentsOf: $0) }
            withUnsafeBytes(of: sampleRate.littleEndian) { wavData.append(contentsOf: $0) }
            withUnsafeBytes(of: byteRate.littleEndian) { wavData.append(contentsOf: $0) }
            withUnsafeBytes(of: UInt16(1).littleEndian) { wavData.append(contentsOf: $0) }
            withUnsafeBytes(of: UInt16(8).littleEndian) { wavData.append(contentsOf: $0) }
            wavData.append("data".data(using: .ascii)!)
            withUnsafeBytes(of: numSamples.littleEndian) { wavData.append(contentsOf: $0) }
            wavData.append(Data(repeating: 128, count: Int(numSamples)))

            audioPlayer = try AVAudioPlayer(data: wavData)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 0.0
            audioPlayer?.play()
        } catch {
            // Ignore audio setup errors
        }
    }
}

struct WalkerConsoleView: View {
    @StateObject private var controller = IslandWalkerController()

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#09090B").ignoresSafeArea()

            // 前景「島頂屋脊軌道」：點擊即可戳出隨機台詞泡泡！
            VStack(spacing: 4) {
                WalkerSpriteView(
                    stepIndex: controller.stepIndex,
                    facingLeft: controller.facingLeft,
                    isStationary: controller.isStationary
                )
                .frame(width: 32, height: 32)
                .offset(x: CGFloat(controller.positionX))
                .animation(.linear(duration: 0.2), value: controller.positionX)
                .onTapGesture {
                    controller.pokePet()
                }

                if !controller.bubbleText.isEmpty {
                    Text(controller.bubbleText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "#09090B"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#F472B6"))
                        .clipShape(Capsule())
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.top, 2)

            VStack(spacing: 18) {
                Spacer().frame(height: 82)

                VStack(spacing: 14) {
                    HStack {
                        Text("CHI OU STUDIO // 池鷗")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#F472B6"))
                        Spacer()
                        Button("👉 戳一下換台詞") {
                            controller.pokePet()
                        }
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#F472B6"))
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black)
                            .frame(height: 124)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(hex: "#F472B6").opacity(0.4), lineWidth: 1.5)
                            )

                        VStack(spacing: 6) {
                            if !controller.bubbleText.isEmpty {
                                Text(controller.bubbleText)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#09090B"))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: "#F472B6"))
                                    .clipShape(Capsule())
                            }

                            WalkerSpriteView(
                                stepIndex: controller.stepIndex,
                                facingLeft: controller.facingLeft,
                                isStationary: controller.isStationary
                            )
                            .frame(width: 56, height: 56)
                            .offset(x: CGFloat(controller.positionX * 1.6))
                        }
                    }
                    .onTapGesture {
                        controller.pokePet()
                    }

                    Text(controller.statusLog)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(hex: "#FDA4AF"))
                        .multilineTextAlignment(.center)
                }
                .padding(18)
                .background(Color(hex: "#121216"))
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

                VStack(spacing: 10) {
                    Button(action: {
                        if controller.isIslandActive {
                            controller.stopIslandWalk()
                        } else {
                            controller.startIslandWalk()
                        }
                    }) {
                        Text(controller.isIslandActive ? "召回「池鷗」休息" : "送「池鷗」上動態島")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(hex: "#09090B"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#F472B6"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // 隨時在 iPhone 切換「📍原地站著不動」或「🚶左右來回散步」
                    Button(action: {
                        controller.toggleStationaryMode()
                    }) {
                        Text(controller.isStationary
                             ? "動作模式：📍 原地站著不動 (點擊切換為左右散步)"
                             : "動作模式：🚶 左右來回散步 (點擊切換為原地站著不動)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#F472B6"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#18181B"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#F472B6").opacity(0.45), lineWidth: 1)
                            )
                    }

                    Button(action: {
                        controller.toggleEngineMode()
                    }) {
                        Text(controller.isEcoMode
                             ? "驅動引擎：B. 省電秒數推進 (點擊切換為流暢保活)"
                             : "驅動引擎：A. 靜音背景流暢保活 (點擊切換為省電模式)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#18181B"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 22)
        }
    }
}
