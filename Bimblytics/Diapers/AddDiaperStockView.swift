//
//  AddDiaperStockView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 07/04/2026.
//

import SwiftUI
import SwiftData

struct AddDiaperStockView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<InventoryLocation> { location in
            !location.isArchived
        },
        sort: [
            SortDescriptor(\InventoryLocation.sortOrder),
            SortDescriptor(\InventoryLocation.name)
        ]
    )
    private var locations: [InventoryLocation]

    let diaperSize: DiaperSize

    @State private var quantityText: String = ""
    @State private var purchaseDate: Date = .now
    @State private var selectedLocationId: PersistentIdentifier?
    @State private var totalPrice: Decimal?
    @State private var notes: String = ""
    @State private var errorMessage: String?

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "EUR"
    }

    var body: some View {
        Form {
            Section("Diaper") {
                LabeledContent("Brand", value: diaperSize.model?.brand?.name ?? "-")
                LabeledContent("Model", value: diaperSize.model?.name ?? "-")
                LabeledContent("Size", value: diaperSize.displayName)

                if !diaperSize.sizeRange.isEmpty {
                    LabeledContent("Range", value: diaperSize.sizeRange)
                }
            }

            Section("Purchase") {
                TextField("Quantity", text: $quantityText)
                    .keyboardType(.numberPad)

                DatePicker("Date", selection: $purchaseDate, displayedComponents: .date)

                Picker("Location", selection: $selectedLocationId) {
                    ForEach(locations) { location in
                        Text(location.name)
                            .tag(Optional(location.persistentModelID))
                    }
                }
            }

            Section("Optional") {
                HStack(spacing: 12) {
                    Text(currencyCode)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)

                    TextField("Total price", value: $totalPrice, format: .number)
                        .keyboardType(.decimalPad)
                }

                if let unitPrice {
                    LabeledContent("Unit price") {
                        Text(unitPrice.formatted(
                            .currency(code: currencyCode)
                                .locale(Locale.current)
                        ))
                    }
                }

                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(AppColors.accent)
                }
            }
        }
        .background(AppColors.background)
        .navigationTitle("Add stock")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    savePurchase()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)
                .disabled(!canSave)
            }
        }
        .onAppear {
            if selectedLocationId == nil {
                selectedLocationId = defaultLocation?.persistentModelID
            }
        }
    }

    private var defaultLocation: InventoryLocation? {
        locations.first(where: { $0.isDefault }) ?? locations.first
    }

    private var selectedLocation: InventoryLocation? {
        guard let selectedLocationId else {
            return nil
        }

        return locations.first(where: { $0.persistentModelID == selectedLocationId })
    }

    private var parsedQuantity: Int? {
        guard let quantity = Int(quantityText.trimmingCharacters(in: .whitespacesAndNewlines)), quantity > 0 else {
            return nil
        }

        return quantity
    }

    private var unitPrice: Decimal? {
        guard let totalPrice, let parsedQuantity, parsedQuantity > 0 else {
            return nil
        }

        return totalPrice / Decimal(parsedQuantity)
    }

    private var canSave: Bool {
        parsedQuantity != nil && selectedLocation != nil
    }

    private func savePurchase() {
        guard let quantity = parsedQuantity else {
            errorMessage = "Enter a valid quantity greater than zero."
            return
        }

        guard let location = selectedLocation else {
            errorMessage = "Select a location."
            return
        }

        do {
            let service = DiaperInventoryService(modelContext: modelContext)

            try service.addStock(
                for: diaperSize,
                in: location,
                quantity: quantity,
                type: .purchase,
                note: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
                reference: nil,
                createdAt: purchaseDate,
                totalPrice: totalPrice,
                currencyCode: currencyCode
            )

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("Add Diaper Stock") {
    let container = DiaperInventoryPreviewData.makeContainer()
    let context = container.mainContext
    let descriptor = FetchDescriptor<DiaperSize>(
        sortBy: [
            SortDescriptor(\DiaperSize.code)
        ]
    )
    let diaperSize = (try? context.fetch(descriptor).first) ?? DiaperSize(
        code: "3",
        descriptionText: "Midi",
        sizeRange: "4 - 9 kg",
        source: .userCustom
    )

    return NavigationStack {
        AddDiaperStockView(diaperSize: diaperSize)
    }
    .modelContainer(container)
}

#Preview("Add Diaper Stock - Dark") {
    let container = DiaperInventoryPreviewData.makeContainer()
    let context = container.mainContext
    let descriptor = FetchDescriptor<DiaperSize>(
        sortBy: [
            SortDescriptor(\DiaperSize.code)
        ]
    )
    let diaperSize = (try? context.fetch(descriptor).first) ?? DiaperSize(
        code: "3",
        descriptionText: "Midi",
        sizeRange: "4 - 9 kg",
        source: .userCustom
    )

    return NavigationStack {
        AddDiaperStockView(diaperSize: diaperSize)
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
