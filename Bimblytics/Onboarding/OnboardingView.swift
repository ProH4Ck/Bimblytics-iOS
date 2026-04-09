//
//  OnboardingView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 06/04/2026.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {

    private enum Step: Int, CaseIterable {
        case welcome
        case diapers
        case babyInfo
    }
    
    @Environment(\.modelContext) private var modelContext

    // Local form state
    @State private var currentStep: Step = .welcome
    @State private var name: String = ""
    @State private var birthDate: Date = Date()
    @State private var gender: Gender = .male
    @State private var diaperEnabled: Bool = true

    let onComplete: (Baby) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                TabView(selection: $currentStep) {
                    introCard(
                        title: "Welcome to Bimblytics",
                        subtitle: "Track the most important moments of your baby's day.",
                        description: "Bimblytics helps you track and monitor daily activities such as diaper changes, sleep, feeding, and other useful events, so everything is always at your fingertips.",
                        systemIcon: nil,
                        icon: nil,
                        buttonTitle: "Continue",
                        buttonAction: {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                                currentStep = .diapers
                            }
                        }
                    )
                    .tag(Step.welcome)
                    .padding(.horizontal, 10)
                    .scaleEffect(currentStep == .welcome ? 1.0 : 0.965)
                    .opacity(currentStep == .welcome ? 1.0 : 0.72)
                    .offset(y: currentStep == .welcome ? 0 : 10)
                    .animation(.spring(response: 0.38, dampingFraction: 0.88), value: currentStep)

                    introCard(
                        title: "Track diaper changes",
                        subtitle: "Log every change and stay on top of your diaper stock.",
                        description: "Record every diaper change, keep your diaper inventory updated, and receive alerts when your stock drops below the threshold you set.",
                        systemIcon: nil,
                        icon: "DiaperIcon",
                        buttonTitle: "Set up your baby",
                        buttonAction: {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                                currentStep = .babyInfo
                            }
                        }
                    )
                    .tag(Step.diapers)
                    .padding(.horizontal, 10)
                    .scaleEffect(currentStep == .diapers ? 1.0 : 0.965)
                    .opacity(currentStep == .diapers ? 1.0 : 0.72)
                    .offset(y: currentStep == .diapers ? 0 : 10)
                    .animation(.spring(response: 0.38, dampingFraction: 0.88), value: currentStep)

                    formCard
                        .tag(Step.babyInfo)
                        .padding(.horizontal, 10)
                        .scaleEffect(currentStep == .babyInfo ? 1.0 : 0.965)
                        .opacity(currentStep == .babyInfo ? 1.0 : 0.72)
                        .offset(y: currentStep == .babyInfo ? 0 : 10)
                        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: currentStep)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator
            }
            .background(Color(AppColors.background))
            .appScreen()
            .navigationBarHidden(true)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases, id: \.self) { step in
                Capsule()
                    .fill(currentStep == step ? AppColors.accent : AppColors.textSecondary.opacity(0.22))
                    .frame(width: currentStep == step ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.82), value: currentStep)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(AppColors.surface)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(AppColors.textSecondary.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private var formCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("Set up your baby's profile")
                    .appText(.largeTitle)
                    .multilineTextAlignment(.center)

                Text("Enter your baby's details and choose which features you want to enable right away.")
                    .appText(.bodySecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            ScrollView {
                VStack(spacing: 20) {
                    formSection(title: "Baby information") {
                        VStack(spacing: 16) {
                            formFieldLabel("Name")
                            TextField("Enter your baby's name", text: $name)
                                .appInputField()

                            VStack(alignment: .leading, spacing: 8) {
                                formFieldLabel("Birth date")
                                DatePicker(
                                    "Birth date",
                                    selection: $birthDate,
                                    in: ...Date(),
                                    displayedComponents: .date
                                )
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .appInputField()
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                formFieldLabel("Gender")
                                Picker("Gender", selection: $gender) {
                                    ForEach(Gender.allCases) { g in
                                        Text(g.rawValue).tag(g)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                    }

                    formSection(title: "Features") {
                        VStack(spacing: 12) {
                            featureToggleRow(title: "Track diapers", isOn: $diaperEnabled)
                        }
                    }

                    Text("You can change these settings later.")
                        .appText(.captionSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Continue", action: continueTapped)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AppColors.accent.opacity(0.25), lineWidth: 4)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .appText(.headline)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppColors.textSecondary.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func formFieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(AppColors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func featureToggleRow(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.body)
        }
        .tint(AppColors.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.background)
        )
    }

    private func introCard(
        title: String,
        subtitle: String,
        description: String,
        systemIcon: String?,
        icon: String?,
        buttonTitle: String,
        buttonAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                Spacer(minLength: 0)

                if let systemIcon {
                    Image(systemName: systemIcon)
                        .font(.system(size: 54))
                        .foregroundStyle(AppColors.accent)
                        .padding(24)
                        .background(
                            Circle()
                                .fill(AppColors.secondary.opacity(0.12))
                        )
                } else if let icon {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundStyle(AppColors.secondary)
                        .padding(20)
                        .background(
                            Circle()
                                .fill(AppColors.secondary.opacity(0.12))
                        )
                } else {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(AppColors.background)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                }

                VStack(spacing: 12) {
                    Text(title)
                        .appText(.largeTitle)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .appText(.headline)
                        .multilineTextAlignment(.center)

                    Text(description)
                        .appText(.bodySecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }

                Spacer(minLength: 0)

                Button(buttonTitle, action: buttonAction)
                    .buttonStyle(PrimaryButtonStyle())

                Button("Skip", action: skipToForm)
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.top, 8)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AppColors.accent.opacity(0.25), lineWidth: 4)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func skipToForm() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
            currentStep = .babyInfo
        }
    }

    private func continueTapped() {
        let newBaby = Baby(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            birthDate: birthDate,
            gender: gender,
            diaperEnabled: diaperEnabled
        )

        modelContext.insert(newBaby)

        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onComplete(newBaby)
        } catch {
            assertionFailure("Failed to save Baby to SwiftData: \(error)")
        }
    }
}

#Preview("Onboarding") {
    OnboardingView { _ in }
}
#Preview ("Onboarding Dark") {
    OnboardingView { _ in }
        .preferredColorScheme(.dark)
}
