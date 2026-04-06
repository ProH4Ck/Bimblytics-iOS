//
//  OnboardingView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 06/04/2026.
//


import SwiftUI

struct OnboardingView: View {

    private enum Step: Int, CaseIterable {
        case welcome
        case diapers
        case babyInfo
    }

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
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)
            .background(Color(AppColors.background))
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
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Enter your baby's details and choose which features you want to enable right away.")
                    .font(.body)
                    .foregroundStyle(AppColors.textSecondary)
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
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(AppColors.background)
                                )

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
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(AppColors.background)
                                )
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
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: continueTapped) {
                        Text("Continue")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.primary)
                    .shadow(color: AppColors.primary.opacity(0.20), radius: 14, x: 0, y: 8)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
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
                .font(.headline)
                .fontWeight(.semibold)

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
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.primary)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(description)
                        .font(.body)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }

                Spacer(minLength: 0)

                Button(action: buttonAction) {
                    Text(buttonTitle)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)

                Button(action: skipToForm) {
                    Text("Skip")
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.primary)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.bottom, 48)
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
        onComplete(newBaby)
    }
}

#Preview {
    OnboardingView { _ in }
}
