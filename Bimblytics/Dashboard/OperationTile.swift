//
//  OperationTile.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 04/04/2026.
//

import SwiftUI

struct OperationTile: View {
    let item: OperationItem

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer()
                    item.icon
                        .renderingMode(.template)
                }
                Spacer(minLength: 0)
                Text(item.title)
                    .font(.headline)
                Text(item.subtitle)
                    .font(.footnote)
            }
            .padding(12)
        }
        .frame(height: 120)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title). \(item.subtitle)")
    }
}
