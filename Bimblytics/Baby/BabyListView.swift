//
//  BabyListView.swift
//  Bimblytics
//
//  Created by Emanuele Curati on 12/04/2026.
//

import SwiftUI
import SwiftData
import AuthenticationServices
import CryptoKit
internal import Combine

@MainActor
struct BabyListView<AuthService: BimblyticsAuthServicing, FamilyService: BimblyticsFamilyServicing, DeviceService: BimblyticsDeviceServicing, BabyService: BimblyticsBabyServicing, SyncService: BimblyticsSyncServicing>: View {
    @Query(sort: \Baby.name, order: .forward) private var babies: [Baby]
    @Query(sort: \SyncedFamily.name, order: .forward) private var syncedFamilies: [SyncedFamily]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddBaby = false
    @State private var showingCreateFamilyWizard = false
    @State private var showingJoinFamily = false
    @State private var showingInvitation = false
    @State private var invitationFamily: BimblyticsFamily?
    @State private var invitationToken: String?
    @State private var showingLogoutConfirmation = false
    @StateObject private var authenticationService: AuthService
    @StateObject private var familyService: FamilyService
    @StateObject private var deviceService: DeviceService
    @StateObject private var babyService: BabyService
    @StateObject private var syncService: SyncService
    @State private var authenticationErrorMessage: String?
    @State private var familyErrorMessage: String?

    private var syncedFamilyGroups: [SyncedFamilyGroup] {
        syncedFamilies.map { family in
            SyncedFamilyGroup(
                family: family,
                babies: babies
                    .filter { $0.familyId?.caseInsensitiveCompare(family.familyId) == .orderedSame }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            )
        }
    }

    private var babiesWithoutSyncedFamily: [Baby] {
        babies
            .filter { baby in
                guard let familyId = baby.familyId else {
                    return true
                }

                return !syncedFamilies.contains {
                    $0.familyId.caseInsensitiveCompare(familyId) == .orderedSame
                }
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var accountFamiliesNotSyncedOnDevice: [BimblyticsFamily] {
        familyService.families
            .filter { family in
                !syncedFamilies.contains {
                    $0.familyId.caseInsensitiveCompare(family.id) == .orderedSame
                }
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var babiesAvailableForNewFamily: [Baby] {
        babies.filter { $0.familyId == nil }
    }

    private var canCreateFamily: Bool {
        !babiesAvailableForNewFamily.isEmpty
    }

    init(
        authenticationService: AuthService,
        familyService: FamilyService,
        deviceService: DeviceService,
        babyService: BabyService,
        syncService: SyncService,
        invitationToken: String? = nil
    ) {
        _showingJoinFamily = State(initialValue: invitationToken != nil)
        _authenticationService = StateObject(wrappedValue: authenticationService)
        _familyService = StateObject(wrappedValue: familyService)
        _deviceService = StateObject(wrappedValue: deviceService)
        _babyService = StateObject(wrappedValue: babyService)
        _syncService = StateObject(wrappedValue: syncService)
        _invitationToken = State(initialValue: invitationToken)
    }

    var body: some View {
        NavigationStack {
            List {
                babySections

                Section {
                    if authenticationService.isAuthenticated {
                        if familyService.isLoading {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .controlSize(.small)

                                Text("Loading families...")
                                    .foregroundStyle(.secondary)
                            }
                        } else if accountFamiliesNotSyncedOnDevice.isEmpty && syncedFamilies.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("No families yet")
                                    .font(.subheadline.weight(.semibold))
                                Text("Create your first family to start sharing baby tracking.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } else if !accountFamiliesNotSyncedOnDevice.isEmpty {
                            ForEach(accountFamiliesNotSyncedOnDevice) { family in
                                unsyncedAccountFamilyRow(family)
                            }
                        }

                        if let familyErrorMessage {
                            Text(familyErrorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        Button {
                            showingCreateFamilyWizard = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.primary.opacity(0.15))
                                    Image(systemName: "person.3.fill")
                                        .foregroundStyle(AppColors.primary)
                                }
                                .frame(width: 36, height: 36)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Create family")
                                        .foregroundStyle(AppColors.primary)
                                    Text(canCreateFamily ? "Invite caregivers and share baby tracking" : "All babies are already in a family")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Create family")
                        .disabled(!canCreateFamily)

                        Button {
                            invitationToken = nil
                            showingJoinFamily = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.accent.opacity(0.15))
                                    Image(systemName: "qrcode.viewfinder")
                                        .foregroundStyle(AppColors.accent)
                                }
                                .frame(width: 36, height: 36)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Join an existing family")
                                        .foregroundStyle(AppColors.primary)
                                    Text("Scan an invitation QR code")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Join an existing family")

                        Button(role: .destructive) {
                            showingLogoutConfirmation = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.12))
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .foregroundStyle(.red)
                                }
                                .frame(width: 36, height: 36)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Logout")
                                    Text("Disconnect from Bimblytics.Auth")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Logout")
                    } else {
                        Button {
                            Task {
                                do {
                                    try await authenticationService.signIn()
                                    authenticationErrorMessage = nil
                                } catch {
                                    authenticationErrorMessage = error.localizedDescription
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.primary.opacity(0.15))
                                    Image(systemName: "person.badge.key.fill")
                                        .foregroundStyle(AppColors.primary)
                                }
                                .frame(width: 36, height: 36)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sign in or register")
                                        .foregroundStyle(AppColors.primary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Sign in or register")
                    }
                }
                
                if let authenticationErrorMessage {
                    Section {
                        Text(authenticationErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .background(AppColors.background)
            .navigationTitle("Babies")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showingAddBaby) {
                BabyDetailView(baby: nil)
            }
            .navigationDestination(isPresented: $showingCreateFamilyWizard) {
                FamilySetupWizardView(
                    babies: babies,
                    authenticationService: authenticationService,
                    familyService: familyService,
                    deviceService: deviceService,
                    babyService: babyService,
                    syncService: syncService
                )
            }
            .navigationDestination(isPresented: $showingJoinFamily) {
                JoinFamilyInvitationView(
                    initialToken: invitationToken,
                    authenticationService: authenticationService,
                    familyService: familyService,
                    deviceService: deviceService,
                    syncService: syncService
                )
            }
            .navigationDestination(isPresented: $showingInvitation) {
                if let invitationFamily {
                    FamilyInvitationQRCodeView(
                        family: invitationFamily,
                        authenticationService: authenticationService,
                        familyService: familyService
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAddBaby = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(AppColors.primary)
                    }
                    .accessibilityLabel("Add baby")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(AppColors.primary)
                    }
                }
            }
            .onOpenURL { url in
                if let token = AppEnvironment.familyInvitationToken(from: url) {
                    invitationToken = token
                    showingJoinFamily = true
                } else {
                    authenticationService.handleCallback(url)
                }
            }
            .confirmationDialog(
                "Disconnect account?",
                isPresented: $showingLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Logout", role: .destructive) {
                    authenticationService.logout()
                }

                Button("Cancel", role: .cancel) {
                }
            } message: {
                Text("You will be disconnected from Bimblytics.Auth on this device.")
            }
            .task(id: authenticationService.isAuthenticated) {
                guard authenticationService.isAuthenticated else {
                    familyService.clear()
                    familyErrorMessage = nil
                    return
                }

                do {
                    let accessToken = try await authenticationService.validAccessToken()
                    try await familyService.loadFamilies(accessToken: accessToken)
                    familyErrorMessage = nil
                } catch {
                    familyErrorMessage = error.localizedDescription
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var babySections: some View {
        if syncedFamilies.isEmpty {
            ForEach(babies) { baby in
                babyRow(baby)
            }
        } else {
            ForEach(syncedFamilyGroups) { group in
                Section(group.family.name) {
                    if group.babies.isEmpty {
                        Text("No babies synced on this device.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(group.babies) { baby in
                            babyRow(baby)
                        }
                    }

                    familyActions(for: BimblyticsFamily(
                        id: group.family.familyId,
                        name: group.family.name
                    ))
                }
            }

            if !babiesWithoutSyncedFamily.isEmpty {
                Section("On this device") {
                    ForEach(babiesWithoutSyncedFamily) { baby in
                        babyRow(baby)
                    }
                }
            }
        }
    }

    private func babyRow(_ baby: Baby) -> some View {
        NavigationLink {
            BabyDetailView(baby: baby)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(baby.gender == .male ? AppColors.colorMale : AppColors.colorFemale)
                    Image(systemName: "person.fill")
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading) {
                    Text(baby.name)
                    Text(baby.ageText())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func unsyncedAccountFamilyRow(_ family: BimblyticsFamily) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.15))
                Image(systemName: "house.fill")
                    .foregroundStyle(AppColors.accent)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(family.name)
                    .font(.subheadline.weight(.semibold))
                Text("Not synced on this device")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                Button {
                    showInvitation(for: family)
                } label: {
                    Label("Invite people", systemImage: "person.badge.plus")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(AppColors.primary)
            }
            .accessibilityLabel("Actions for \(family.name)")
        }
    }

    private func familyActions(for family: BimblyticsFamily) -> some View {
        Menu {
            Button {
                showInvitation(for: family)
            } label: {
                Label("Invite people", systemImage: "person.badge.plus")
            }
        } label: {
            Label("Family options", systemImage: "ellipsis.circle")
                .foregroundStyle(AppColors.primary)
        }
        .accessibilityLabel("Actions for \(family.name)")
    }

    private func showInvitation(for family: BimblyticsFamily) {
        invitationFamily = family
        showingInvitation = true
    }
}

private struct SyncedFamilyGroup: Identifiable {
    let family: SyncedFamily
    let babies: [Baby]

    var id: String {
        family.familyId
    }
}

extension BabyListView where AuthService == BimblyticsAuthService, FamilyService == BimblyticsFamilyService, DeviceService == BimblyticsDeviceService, BabyService == BimblyticsBabyService, SyncService == BimblyticsSyncService {
    init(invitationToken: String? = nil) {
        self.init(
            authenticationService: BimblyticsAuthService(),
            familyService: BimblyticsFamilyService(),
            deviceService: BimblyticsDeviceService(),
            babyService: BimblyticsBabyService(),
            syncService: BimblyticsSyncService(),
            invitationToken: invitationToken
        )
    }
}

private struct FamilySetupWizardView<AuthService: BimblyticsAuthServicing, FamilyService: BimblyticsFamilyServicing, DeviceService: BimblyticsDeviceServicing, BabyService: BimblyticsBabyServicing, SyncService: BimblyticsSyncServicing>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DiaperChangeEvent.createdAt, order: .forward) private var diaperChangeEvents: [DiaperChangeEvent]
    @Query(sort: \FeedingEvent.createdAt, order: .forward) private var feedingEvents: [FeedingEvent]
    @Query private var diaperBrands: [DiaperBrand]
    @Query private var diaperModels: [DiaperModel]
    @Query private var diaperSizes: [DiaperSize]
    @Query private var inventoryLocations: [InventoryLocation]
    @Query private var diaperInventoryItems: [DiaperInventoryItem]
    @Query private var diaperStockMovements: [DiaperStockMovement]
    @Query(sort: \FoodCategory.sortOrder, order: .forward) private var foodCategories: [FoodCategory]
    @Query(sort: \FoodUnit.sortOrder, order: .forward) private var foodUnits: [FoodUnit]
    @Query(sort: \FoodItem.name, order: .forward) private var foodItems: [FoodItem]
    let babies: [Baby]
    @ObservedObject var authenticationService: AuthService
    @ObservedObject var familyService: FamilyService
    @ObservedObject var deviceService: DeviceService
    @ObservedObject var babyService: BabyService
    @ObservedObject var syncService: SyncService

    @State private var familyName = ""
    @State private var selectedBabyIds = Set<UUID>()
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var babiesAvailableForNewFamily: [Baby] {
        babies.filter { $0.familyId == nil }
    }

    private var canSave: Bool {
        !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && authenticationService.isAuthenticated && !selectedBabyIds.isEmpty && !isSaving
    }

    var body: some View {
        Form {
            Section {
                TextField("Family name", text: $familyName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
            } header: {
                Text("New family")
            } footer: {
                Text("Create a shared space for babies, caregivers and activity tracking.")
            }

            Section {
                if babiesAvailableForNewFamily.isEmpty {
                    Text("No babies available on this device.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(babiesAvailableForNewFamily) { baby in
                        Button {
                            toggleBabySelection(baby)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(baby.gender == .male ? AppColors.colorMale : AppColors.colorFemale)
                                    Image(systemName: "person.fill")
                                }
                                .frame(width: 36, height: 36)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(baby.name)
                                        .foregroundStyle(.primary)
                                    Text(baby.ageText())
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: selectedBabyIds.contains(baby.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedBabyIds.contains(baby.id) ? AppColors.primary : AppColors.secondary)
                                    .font(.title3)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("Babies")
            } footer: {
                Text("Select the babies that should be associated with the new family.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .disabled(isSaving)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .overlay {
            if isSaving {
                ZStack {
                    Color.black.opacity(0.08)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())

                    VStack(spacing: 14) {
                        ProgressView()
                            .controlSize(.large)

                        Text("Creating family...")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("Syncing local data")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
                    .accessibilityElement(children: .combine)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSaving)
        .navigationTitle("Create family")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(AppColors.primary)
                }
                .accessibilityLabel("Cancel")
                .disabled(isSaving)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await saveFamily()
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "checkmark")
                            .foregroundStyle(AppColors.primary)
                    }
                }
                .accessibilityLabel("Save family")
                .disabled(!canSave)
            }
        }
        .onAppear {
            selectedBabyIds = Set(babiesAvailableForNewFamily.map(\.id))
        }
    }

    private func toggleBabySelection(_ baby: Baby) {
        if selectedBabyIds.contains(baby.id) {
            selectedBabyIds.remove(baby.id)
        } else {
            selectedBabyIds.insert(baby.id)
        }
    }

    private func saveFamily() async {
        let trimmedFamilyName = familyName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedFamilyName.isEmpty else {
            errorMessage = "Family name is required."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let accessToken = try await authenticationService.validAccessToken()
            let deviceId = try await deviceService.registerDevice(accessToken: accessToken)
            let family = try await familyService.createFamily(name: trimmedFamilyName, accessToken: accessToken)

            for baby in babiesAvailableForNewFamily where selectedBabyIds.contains(baby.id) {
                try await babyService.createBaby(
                    familyId: family.id,
                    baby: baby,
                    deviceId: deviceId,
                    accessToken: accessToken
                )
            }

            let localStore = SyncedFamilyLocalStore(modelContext: modelContext)
            try localStore.saveFamily(family, linkedBabyIds: selectedBabyIds)
            try assignLocalData(toFamilyId: family.id)

            try await syncLocalData(
                familyId: family.id,
                deviceId: deviceId,
                accessToken: accessToken
            )

            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func assignLocalData(toFamilyId familyId: String) throws {
        for baby in babies where selectedBabyIds.contains(baby.id) {
            baby.familyId = familyId
        }

        for brand in diaperBrands where brand.familyId == nil {
            brand.familyId = familyId
        }

        for model in diaperModels where model.familyId == nil {
            model.familyId = familyId
        }

        for size in diaperSizes where size.familyId == nil {
            size.familyId = familyId
        }

        for location in inventoryLocations where location.familyId == nil {
            location.familyId = familyId
        }

        for item in diaperInventoryItems where item.familyId == nil {
            item.familyId = familyId
        }

        for movement in diaperStockMovements where movement.familyId == nil {
            movement.familyId = familyId
        }

        for category in foodCategories where category.familyId == nil {
            category.familyId = familyId
        }

        for unit in foodUnits where unit.familyId == nil {
            unit.familyId = familyId
        }

        for foodItem in foodItems where foodItem.familyId == nil {
            foodItem.familyId = familyId
        }

        try modelContext.save()
    }

    private func syncLocalData(
        familyId: String,
        deviceId: UUID,
        accessToken: String
    ) async throws {
        guard let familyUuid = UUID(uuidString: familyId) else {
            throw FamilySetupWizardError.invalidFamilyId
        }

        let selectedBabies = babies.filter { selectedBabyIds.contains($0.id) }
        let selectedBabyIdSet = Set(selectedBabies.map(\.id))

        var localChanges: [ClientSyncChangeRequest] = []

        for category in foodCategories where category.familyId == familyId {
            try localChanges.append(.upsert(
                familyId: familyUuid,
                entityType: "FoodCategory",
                entityId: category.id,
                changedAt: category.updatedAt,
                payload: FoodCategoryClientSyncPayload(
                    id: category.id,
                    familyId: familyUuid,
                    name: category.name,
                    sortOrder: category.sortOrder,
                    isSystem: category.isSystem,
                    isArchived: category.isArchived,
                    createdAt: category.createdAt,
                    updatedAt: category.updatedAt,
                    deletedAt: nil,
                    createdByUserId: deviceId,
                    createdByDeviceId: deviceId,
                    lastModifiedByUserId: deviceId,
                    lastModifiedByDeviceId: deviceId,
                    version: 1
                )
            ))
        }

        for unit in foodUnits where unit.familyId == familyId {
            try localChanges.append(.upsert(
                familyId: familyUuid,
                entityType: "FoodUnit",
                entityId: unit.id,
                changedAt: unit.updatedAt,
                payload: FoodUnitClientSyncPayload(
                    id: unit.id,
                    familyId: familyUuid,
                    name: unit.name,
                    symbol: unit.symbol,
                    sortOrder: unit.sortOrder,
                    isSystem: unit.isSystem,
                    isArchived: unit.isArchived,
                    createdAt: unit.createdAt,
                    updatedAt: unit.updatedAt,
                    deletedAt: nil,
                    createdByUserId: deviceId,
                    createdByDeviceId: deviceId,
                    lastModifiedByUserId: deviceId,
                    lastModifiedByDeviceId: deviceId,
                    version: 1
                )
            ))
        }

        for foodItem in foodItems where foodItem.familyId == familyId {
            try localChanges.append(.upsert(
                familyId: familyUuid,
                entityType: "FoodItem",
                entityId: foodItem.id,
                changedAt: foodItem.updatedAt,
                payload: FoodItemClientSyncPayload(
                    id: foodItem.id,
                    familyId: familyUuid,
                    name: foodItem.name,
                    categoryId: foodItem.category?.id,
                    defaultUnitId: foodItem.defaultUnit?.id,
                    createdAt: foodItem.createdAt,
                    updatedAt: foodItem.updatedAt,
                    deletedAt: nil,
                    createdByUserId: deviceId,
                    createdByDeviceId: deviceId,
                    lastModifiedByUserId: deviceId,
                    lastModifiedByDeviceId: deviceId,
                    version: 1
                )
            ))
        }

        for event in diaperChangeEvents where selectedBabyIdSet.contains(event.babyId) {
            try localChanges.append(.upsert(
                familyId: familyUuid,
                entityType: "DiaperChangeEvent",
                entityId: event.id,
                changedAt: event.createdAt,
                payload: DiaperChangeEventClientSyncPayload(
                    id: event.id,
                    familyId: familyUuid,
                    babyId: event.babyId,
                    eventDate: event.date,
                    diaperInventoryItemId: nil,
                    inventoryLocationId: event.location?.id,
                    stockMovementId: event.stockMovementId.flatMap(UUID.init(uuidString:)),
                    peeLevel: event.peeLevelRaw,
                    poopLevel: event.poopLevelRaw,
                    notes: event.notes,
                    createdAt: event.createdAt,
                    updatedAt: event.createdAt,
                    deletedAt: nil,
                    createdByUserId: deviceId,
                    createdByDeviceId: deviceId,
                    lastModifiedByUserId: deviceId,
                    lastModifiedByDeviceId: deviceId,
                    version: 1
                )
            ))
        }

        for event in feedingEvents where selectedBabyIdSet.contains(event.babyId) {
            try localChanges.append(.upsert(
                familyId: familyUuid,
                entityType: "FeedingEvent",
                entityId: event.id,
                changedAt: event.createdAt,
                payload: FeedingEventClientSyncPayload(
                    id: event.id,
                    familyId: familyUuid,
                    babyId: event.babyId,
                    eventDate: event.eventDate,
                    foodId: event.foodItem?.id,
                    quantity: event.quantity,
                    unit: event.unitSymbol ?? event.unitName,
                    notes: event.notes,
                    createdAt: event.createdAt,
                    updatedAt: event.createdAt,
                    deletedAt: nil,
                    createdByUserId: deviceId,
                    createdByDeviceId: deviceId,
                    lastModifiedByUserId: deviceId,
                    lastModifiedByDeviceId: deviceId,
                    version: 1
                )
            ))
        }

        guard !localChanges.isEmpty else {
            return
        }

        let syncResponse = try await syncService.sync(
            deviceId: deviceId,
            lastKnownServerSequence: 0,
            localChanges: localChanges,
            accessToken: accessToken
        )

        guard syncResponse.conflicts.isEmpty else {
            throw FamilySetupWizardError.syncConflicts(syncResponse.conflicts.count)
        }
    }
}

private enum FamilySetupWizardError: LocalizedError {
    case invalidFamilyId
    case syncConflicts(Int)

    var errorDescription: String? {
        switch self {
        case .invalidFamilyId:
            return "The created family identifier is invalid."
        case .syncConflicts(let count):
            return "Sync completed with \(count) conflict\(count == 1 ? "" : "s")."
        }
    }
}

private struct BabyClientSyncPayload: Encodable {
    let id: UUID
    let familyId: UUID
    let name: String
    let birthDate: String?
    let genderCode: String?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let createdByUserId: UUID
    let createdByDeviceId: UUID
    let lastModifiedByUserId: UUID
    let lastModifiedByDeviceId: UUID
    let version: Int64
}

private struct DiaperChangeEventClientSyncPayload: Encodable {
    let id: UUID
    let familyId: UUID
    let babyId: UUID
    let eventDate: Date
    let diaperInventoryItemId: UUID?
    let inventoryLocationId: UUID?
    let stockMovementId: UUID?
    let peeLevel: Int
    let poopLevel: Int
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let createdByUserId: UUID
    let createdByDeviceId: UUID
    let lastModifiedByUserId: UUID
    let lastModifiedByDeviceId: UUID
    let version: Int64
}

private struct FeedingEventClientSyncPayload: Encodable {
    let id: UUID
    let familyId: UUID
    let babyId: UUID
    let eventDate: Date
    let foodId: UUID?
    let quantity: Double
    let unit: String
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let createdByUserId: UUID
    let createdByDeviceId: UUID
    let lastModifiedByUserId: UUID
    let lastModifiedByDeviceId: UUID
    let version: Int64
}

private struct FoodCategoryClientSyncPayload: Encodable {
    let id: UUID
    let familyId: UUID
    let name: String
    let sortOrder: Int
    let isSystem: Bool
    let isArchived: Bool
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let createdByUserId: UUID
    let createdByDeviceId: UUID
    let lastModifiedByUserId: UUID
    let lastModifiedByDeviceId: UUID
    let version: Int64
}

private struct FoodUnitClientSyncPayload: Encodable {
    let id: UUID
    let familyId: UUID
    let name: String
    let symbol: String
    let sortOrder: Int
    let isSystem: Bool
    let isArchived: Bool
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let createdByUserId: UUID
    let createdByDeviceId: UUID
    let lastModifiedByUserId: UUID
    let lastModifiedByDeviceId: UUID
    let version: Int64
}

private struct FoodItemClientSyncPayload: Encodable {
    let id: UUID
    let familyId: UUID
    let name: String
    let categoryId: UUID?
    let defaultUnitId: UUID?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let createdByUserId: UUID
    let createdByDeviceId: UUID
    let lastModifiedByUserId: UUID
    let lastModifiedByDeviceId: UUID
    let version: Int64
}


#Preview("BabyListView - Signed out") {
    return BabyListView(
        authenticationService: MockedAuthService(isAuthenticated: false),
        familyService: MockedFamilyService(families: []),
        deviceService: MockedDeviceService(),
        babyService: MockedBabyService(),
        syncService: MockedSyncService()
    )
    .modelContainer(PreviewData.makeContainer())
}

#Preview("BabyListView - Signed in") {
    return BabyListView(
        authenticationService: MockedAuthService(isAuthenticated: true),
        familyService: MockedFamilyService(families: BimblyticsFamily.previewFamilies),
        deviceService: MockedDeviceService(),
        babyService: MockedBabyService(),
        syncService: MockedSyncService()
    )
    .modelContainer(PreviewData.makeContainer())
}

#Preview("BabyListView - Dark") {
    return BabyListView(
        authenticationService: MockedAuthService(isAuthenticated: true),
        familyService: MockedFamilyService(families: BimblyticsFamily.previewFamilies),
        deviceService: MockedDeviceService(),
        babyService: MockedBabyService(),
        syncService: MockedSyncService()
    )
    .modelContainer(PreviewData.makeContainer())
    .preferredColorScheme(.dark)
}
