import AppKit
import SwiftUI

private struct MenuBarWindowLifecycleModifier: ViewModifier {
    let onOpen: () -> Void
    let onClose: () -> Void

    func body(content: Content) -> some View {
        content.background(MenuBarWindowLifecycleHook(onOpen: onOpen, onClose: onClose))
    }
}

private struct MenuBarWindowLifecycleHook: NSViewRepresentable {
    let onOpen: () -> Void
    let onClose: () -> Void

    func makeNSView(context: Context) -> HookView {
        let view = HookView()
        view.onOpen = onOpen
        view.onClose = onClose
        return view
    }

    func updateNSView(_ nsView: HookView, context: Context) {
        nsView.onOpen = onOpen
        nsView.onClose = onClose
        nsView.attachIfNeeded()
    }

    final class HookView: NSView {
        var onOpen: (() -> Void)?
        var onClose: (() -> Void)?
        private var observers: [NSObjectProtocol] = []
        private weak var observedWindow: NSWindow?
        private var isOpen = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            attachIfNeeded()
        }

        func attachIfNeeded() {
            guard let window, window !== observedWindow else { return }
            detach()
            observedWindow = window

            observers.append(
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didBecomeKeyNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    self?.markOpen()
                }
            )

            observers.append(
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didResignKeyNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    self?.markClosed()
                }
            )

            if window.isVisible {
                markOpen()
            }
        }

        private func markOpen() {
            guard !isOpen else { return }
            isOpen = true
            onOpen?()
        }

        private func markClosed() {
            guard isOpen else { return }
            if KeychainAccessGate.isPresentingSystemUI { return }
            isOpen = false
            onClose?()
        }

        private func detach() {
            if isOpen {
                markClosed()
            }
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            observers.removeAll()
            observedWindow = nil
        }

        deinit {
            detach()
        }
    }
}

extension View {
    func onMenuBarWindowLifecycle(onOpen: @escaping () -> Void, onClose: @escaping () -> Void) -> some View {
        modifier(MenuBarWindowLifecycleModifier(onOpen: onOpen, onClose: onClose))
    }
}
