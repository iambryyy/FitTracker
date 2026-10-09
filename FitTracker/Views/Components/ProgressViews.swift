//
//  ProgressViews.swift
//  FitTracker
//

import SwiftUI

/// Ring that fills as `value` approaches `goal`, and turns orange past it.
struct CalorieRing: View {
    var consumed: Double
    var goal: Double

    private var fraction: Double {
        goal > 0 ? min(max(consumed / goal, 0), 1) : 0
    }

    private var isOver: Bool { consumed > goal }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.ftTeal.opacity(0.18), lineWidth: 18)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(isOver ? Color.ftOrange : Color.ftTeal, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: fraction)

            VStack(spacing: 2) {
                Text(abs(goal - consumed).wholeNumberText)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(isOver ? Color.ftOrange : Color.primary)
                    .accessibilityIdentifier(AccessibilityID.Dashboard.caloriesRemaining)
                Text(isOver ? "kcal over" : "kcal left")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Dashboard.calorieRing)
    }
}

/// Labelled horizontal bar for one macronutrient.
struct MacroBar: View {
    var title: String
    var consumed: Double
    var target: Double
    var tint: Color

    private var fraction: Double {
        target > 0 ? min(max(consumed / target, 0), 1) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.2))
                    Capsule().fill(tint).frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 8)
            Text("\(consumed.wholeNumberText) / \(target.wholeNumberText) g")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(consumed.wholeNumberText) of \(target.wholeNumberText) grams")
    }
}
