//
//  Title.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI
import AppKit

public struct Title: View {
    public var body: some View {
        HStack(spacing: 5) {
            Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                .resizable()
                .frame(width: 20, height: 20)
            Text("FanCTL")
                .bold()
        }
        .padding(.horizontal, 10)
    }
}

#Preview {
    Title()
}
