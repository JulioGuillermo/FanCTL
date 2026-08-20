//
//  LiquidGlassPanelManager.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import AppKit
import Observation
import SwiftUI

/// Borderless transparent panel that can become key so controls
/// (text fields, sliders…) receive keyboard input.
final class TransparentLiquidPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Shows SwiftUI content in a floating, borderless, transparent NSPanel.
///
/// Because the window is transparent, materials like `.ultraThinMaterial` are
/// able to refract the desktop and the app behind it in real time (Liquid
/// Glass), unlike a native NSSheet which forces an opaque background.
@Observable
final class LiquidGlassPanelManager {
    private var panel: TransparentLiquidPanel?

    /// Presents `content` in a new floating panel centered over `parentWindow`.
    func present<Content: View>(
        _ content: Content,
        relativeTo parentWindow: NSWindow?
    ) {
        close()

        let hosting = NSHostingController(rootView: content)

        let newPanel = TransparentLiquidPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false,
        )

        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.isMovableByWindowBackground = true
        newPanel.level = .floating
        newPanel.hasShadow = false
        newPanel.hidesOnDeactivate = false
        newPanel.isReleasedWhenClosed = false

        newPanel.contentView = hosting.view

        newPanel.layoutIfNeeded()
        let size = hosting.view.fittingSize
        //        newPanel.setContentSize(size)

        if let parent = parentWindow {
            let x = parent.frame.midX - size.width / 2
            let y = parent.frame.midY - size.height / 2
            newPanel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel = newPanel
        newPanel.makeKeyAndOrderFront(nil)
    }

    /// Closes and releases the floating panel, if any.
    func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}
