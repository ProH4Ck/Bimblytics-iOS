//
//  AppContainerStyles.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 07/04/2026.
//


import SwiftUI

struct AppScreenModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
            .background(AppColors.background)
    }
}

struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppColors.surface)
                    .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
            )
    }
}

struct AppSectionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(AppColors.accent.opacity(0.18), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func appScreen() -> some View {
        modifier(AppScreenModifier())
    }

    func appCard() -> some View {
        modifier(AppCardModifier())
    }

    func appSection() -> some View {
        modifier(AppSectionModifier())
    }
}
