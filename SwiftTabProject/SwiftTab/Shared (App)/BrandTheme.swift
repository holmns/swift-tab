//
//  BrandTheme.swift
//  SwiftTab
//
//  Created by Nawat Suangburanakul on 9/11/2568 BE.
//

import SwiftUI

extension Color {
    static let brandPrimary = Color(red: 255/255, green: 151/255, blue: 0/255)
    static let brandSecondary = Color(red: 255/255, green: 183/255, blue: 40/255)
}

extension View {
    /// Secondary button: Liquid Glass on macOS 26+, bordered below.
    @ViewBuilder
    func glassButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// Call-to-action button: prominent Liquid Glass on macOS 26+,
    /// borderedProminent below.
    @ViewBuilder
    func glassProminentButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}
