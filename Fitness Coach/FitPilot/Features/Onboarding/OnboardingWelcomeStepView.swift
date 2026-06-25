//
//  OnboardingWelcomeStepView.swift
//  Fitness Coach
//
//  FitPilot AI — Welcome step for onboarding.
//

import SwiftUI

struct OnboardingWelcomeStepView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ZStack {
                Circle()
                    .fill(OnboardingTheme.accent.opacity(0.16))
                    .frame(width: 88, height: 88)

                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(OnboardingTheme.accent)
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Text("Your command center for getting leaner, stronger, and more consistent.")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text("FitPilot builds your targets, keeps the day simple, and lets Coach handle food, water, weight, and training from natural language.")
                    .font(.body)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                featureRow("Personal calorie and macro targets", icon: "target")
                featureRow("Fast logging for meals, water, weight, and workouts", icon: "bolt.fill")
                featureRow("Daily reviews and coach guidance", icon: "sparkles")
            }

            OnboardingInfoCard(
                title: "Takes about a minute",
                message: "Use your best estimates. You can adjust everything later in Profile.",
                icon: "clock.fill"
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func featureRow(_ text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(OnboardingTheme.accent)
                .frame(width: 24)

            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .onboardingCard()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingWelcomeStepView()
        .padding()
}
