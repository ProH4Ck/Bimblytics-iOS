//
//  AppFormStyles.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 07/04/2026.
//

import SwiftUI

struct AppInputFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.accent.opacity(0.12), lineWidth: 1)
            )
    }
}

extension View {
    func appInputField() -> some View {
        modifier(AppInputFieldModifier())
    }
}
