//
//  MacNameInfo.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct MacNameInfo: View {
    let systemInfo: SystemInfo

    public var body: some View {
        Text("\(systemInfo.computerName) • \(systemInfo.modelIdentifier)")
            .padding(.horizontal, 20)
    }
}

#Preview {
    MacNameInfo(
        systemInfo: SystemInfo(
            computerName: "MacName",
            type: .macBookPro,
            modelIdentifier: "Model"
        )
    )
}
