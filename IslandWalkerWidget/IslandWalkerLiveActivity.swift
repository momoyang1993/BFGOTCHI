//
//  IslandWalkerLiveActivity.swift
//  Target: IslandWalkerWidgetExtension (支援原地定點不動 + 左右散步 + 戳戳冒泡泡)
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

@main
struct IslandWalkerWidgetBundle: WidgetBundle {
    var body: some Widget {
        IslandWalkerLiveActivity()
    }
}

struct IslandWalkerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IslandWalkerAttributes.self) { context in
            Group {
                if #available(iOS 17.0, *) {
                    Button(intent: PokePetIntent()) {
                        LockScreenRunwayView(context: context)
                    }
                    .buttonStyle(.plain)
                } else {
                    LockScreenRunwayView(context: context)
                }
            }
            .activityBackgroundTint(Color.black.opacity(0.92))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    if #available(iOS 17.0, *) {
                        Button(intent: PokePetIntent()) {
                            ExpandedRunwayView(context: context)
                        }
                        .buttonStyle(.plain)
                    } else {
                        ExpandedRunwayView(context: context)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("\(context.attributes.petName) · \(context.state.isStationary ? "📍定點陪伴" : "🚶散步中")")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#F472B6"))
                        Spacer()
                        Text("👉 戳一下換隨機台詞")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                }

            } compactLeading: {
                if !context.state.bubbleText.isEmpty {
                    Text(context.state.bubbleText.prefix(5))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: "#F472B6"))
                        .lineLimit(1)
                } else {
                    Text(context.attributes.petName.prefix(2))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#F472B6"))
                }

            } compactTrailing: {
                ZStack {
                    WalkerSpriteView(
                        stepIndex: context.state.stepIndex,
                        facingLeft: context.state.facingLeft,
                        isStationary: context.state.isStationary
                    )
                    .frame(width: 24, height: 24)
                    .offset(x: CGFloat(context.state.positionX * 0.42))
                }
                .frame(width: 64, height: 26)

            } minimal: {
                WalkerSpriteView(
                    stepIndex: context.state.stepIndex,
                    facingLeft: context.state.facingLeft,
                    isStationary: context.state.isStationary
                )
                .frame(width: 22, height: 22)
            }
        }
    }
}

private struct ExpandedRunwayView: View {
    let context: ActivityViewContext<IslandWalkerAttributes>

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "#121216"))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "#F472B6").opacity(0.35), lineWidth: 1)
                )

            VStack(spacing: 2) {
                if !context.state.bubbleText.isEmpty {
                    Text(context.state.bubbleText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "#09090B"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#F472B6"))
                        .clipShape(Capsule())
                        .lineLimit(1)
                }

                WalkerSpriteView(
                    stepIndex: context.state.stepIndex,
                    facingLeft: context.state.facingLeft,
                    isStationary: context.state.isStationary
                )
                .frame(width: 36, height: 36)
                .offset(x: CGFloat(context.state.positionX * 1.8))
            }
        }
        .frame(height: 62)
    }
}

private struct LockScreenRunwayView: View {
    let context: ActivityViewContext<IslandWalkerAttributes>

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                if !context.state.bubbleText.isEmpty {
                    Text(context.state.bubbleText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "#09090B"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#F472B6"))
                        .clipShape(Capsule())
                }
                WalkerSpriteView(
                    stepIndex: context.state.stepIndex,
                    facingLeft: context.state.facingLeft,
                    isStationary: context.state.isStationary
                )
                .frame(width: 38, height: 38)
                .offset(x: CGFloat(context.state.positionX * 1.8))
            }
            Spacer()
        }
        .frame(height: 68)
        .padding(.horizontal, 16)
    }
}
