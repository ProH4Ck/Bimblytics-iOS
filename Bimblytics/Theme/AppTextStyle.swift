//
//  AppTextStyle.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 07/04/2026.
//


import SwiftUI

enum AppTextStyle {
    case largeTitle
    case title
    case headline
    case body
    case bodySecondary
    case caption
    case captionSecondary

    var font: Font {
        switch self {
        case .largeTitle:
            return .system(size: 32, weight: .bold)
        case .title:
            return .title2.weight(.bold)
        case .headline:
            return .headline
        case .body, .bodySecondary:
            return .body
        case .caption, .captionSecondary:
            return .footnote
        }
    }

    var color: Color {
        switch self {
        case .largeTitle, .title, .headline, .body, .caption:
            return AppColors.textPrimary
        case .bodySecondary, .captionSecondary:
            return AppColors.textSecondary
        }
    }
}

struct AppTextModifier: ViewModifier {
    let style: AppTextStyle

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .foregroundStyle(style.color)
    }
}

extension View {
    func appText(_ style: AppTextStyle) -> some View {
        modifier(AppTextModifier(style: style))
    }
}