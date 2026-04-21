//
//  OperationItem.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 04/04/2026.
//


import Foundation
import SwiftUI

struct OperationItem: Identifiable {
    let id = UUID()
    let icon: Image
    let title: String
    let subtitle: String
    let colors: [Color]
    let kind: OperationKind
}

enum OperationKind: Hashable {
    case diaper
}
