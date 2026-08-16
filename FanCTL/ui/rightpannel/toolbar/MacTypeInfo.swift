//
//  MainInfo.swift
//  FanCTL
//
//  Created by Julio Guillermo Mayo Vidal on 16/08/2026.
//

import SwiftUI

public struct MacTypeInfo: View {
    let systemInfo: SystemInfo
    
    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemInfo.type.iconName)
                .font(.system(size: 25))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(systemInfo.type.rawValue)
                    .font(.title3)
                    .bold()
            }
        }
        .padding(.horizontal, 10)
    }
}


#Preview {
    MacTypeInfo(systemInfo: .init(computerName: "MacBook Pro", type: .macBookPro, modelIdentifier: "Apple Silicon"))
}
