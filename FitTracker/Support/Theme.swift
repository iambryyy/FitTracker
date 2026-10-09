//
//  Theme.swift
//  FitTracker
//

import SwiftUI

// The original FitTracker palette.
extension Color {
    static let ftOrange = Color(red: 231 / 255, green: 111 / 255, blue: 81 / 255)
    static let ftSand = Color(red: 244 / 255, green: 162 / 255, blue: 97 / 255)
    static let ftYellow = Color(red: 233 / 255, green: 196 / 255, blue: 106 / 255)
    static let ftTeal = Color(red: 42 / 255, green: 157 / 255, blue: 143 / 255)
    static let ftDeepTeal = Color(red: 40 / 255, green: 114 / 255, blue: 113 / 255)
    static let ftNavy = Color(red: 38 / 255, green: 70 / 255, blue: 83 / 255)
}

extension ShapeStyle where Self == Color {
    static var ftOrange: Color { Color.ftOrange }
    static var ftSand: Color { Color.ftSand }
    static var ftYellow: Color { Color.ftYellow }
    static var ftTeal: Color { Color.ftTeal }
    static var ftDeepTeal: Color { Color.ftDeepTeal }
    static var ftNavy: Color { Color.ftNavy }
}

extension Double {
    /// Whole number with grouping separators, e.g. `2,450`.
    var wholeNumberText: String {
        formatted(.number.precision(.fractionLength(0)))
    }

    /// Up to one decimal place, e.g. `0.5`, `12`, `7.3`.
    var oneDecimalText: String {
        formatted(.number.precision(.fractionLength(0...1)))
    }
}

/// Rounded card used to group content on scrolling screens.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.ftOrange.opacity(isEnabled ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
