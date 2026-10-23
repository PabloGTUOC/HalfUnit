import HalfUnitCore
import SwiftUI

struct AppLockView: View {
    let isLocked: Bool
    let onUnlock: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "lock.shield")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(Color.teal)
                    .accessibilityHidden(true)

                Text("Half Unit")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                if isLocked {
                    Button {
                        onUnlock()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "faceid")
                            Text("appLock.screen.unlockButton")
                        }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.teal)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("appLock.screen.unlockButton"))
                    .padding(.bottom, 32)
                }
            }
            .padding()
        }
    }
}

struct AppLockShieldContainerView<Content: View>: View {
    let stateMachine: AppLockStateMachine
    @ViewBuilder let content: () -> Content

    var isContentAccessible: Bool {
        stateMachine.isContentAccessible
    }

    var body: some View {
        ZStack {
            content()
                .accessibilityHidden(!isContentAccessible)
                .allowsHitTesting(isContentAccessible)

            if stateMachine.isShielded {
                AppLockView(
                    isLocked: stateMachine.isLocked,
                    onUnlock: {
                        Task { @MainActor in
                            _ = await stateMachine.unlock(
                                reason: AppLocalization.string("appLock.authReason.unlock")
                            )
                        }
                    }
                )
                .accessibilityAddTraits(.isModal)
                .transition(.opacity)
                .zIndex(999)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: stateMachine.isShielded)
    }
}
