//
//  FamilyInvitationViews.swift
//  Bimblytics
//

import AVFoundation
import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI

@MainActor
struct FamilyInvitationQRCodeView<AuthService: BimblyticsAuthServicing, FamilyService: BimblyticsFamilyServicing>: View {
    let family: BimblyticsFamily
    @ObservedObject var authenticationService: AuthService
    @ObservedObject var familyService: FamilyService

    @State private var invitation: FamilyInvitation?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("Creating invitation...")
            } else if let invitation {
                let invitationUrl = AppEnvironment.familyInvitationUrl(token: invitation.token)

                Text("Scan to join \(family.name)")
                    .font(.headline)

                if let image = qrCodeImage(for: invitationUrl.absoluteString) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 280)
                        .padding(16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Text("The invitation expires on \(expirationText(for: invitation.expiresAt)).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                ShareLink(item: invitationUrl) {
                    Label("Share invitation link", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Could not create invitation",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )

                Button("Try again") {
                    Task {
                        await createInvitation()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
        .navigationTitle("Invite caregiver")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await createInvitation()
        }
    }

    private func createInvitation() async {
        isLoading = true
        errorMessage = nil

        do {
            let accessToken = try await authenticationService.validAccessToken()
            invitation = try await familyService.createInvitation(
                familyId: family.id,
                accessToken: accessToken
            )
        } catch {
            invitation = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func expirationText(for expiresAt: String) -> String {
        guard let date = FamilyInvitationDateFormatting.invitationDateFormatter.date(from: expiresAt)
                ?? FamilyInvitationDateFormatting.invitationDateFormatterWithoutFraction.date(from: expiresAt) else {
            return expiresAt
        }

        return FamilyInvitationDateFormatting.displayDateFormatter.string(from: date)
    }

    private func qrCodeImage(for value: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

private enum FamilyInvitationDateFormatting {
    static let invitationDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let invitationDateFormatterWithoutFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}

@MainActor
struct JoinFamilyInvitationView<AuthService: BimblyticsAuthServicing, FamilyService: BimblyticsFamilyServicing, DeviceService: BimblyticsDeviceServicing, SyncService: BimblyticsSyncServicing>: View {
    let initialToken: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @ObservedObject var authenticationService: AuthService
    @ObservedObject var familyService: FamilyService
    @ObservedObject var deviceService: DeviceService
    @ObservedObject var syncService: SyncService

    @State private var joinedFamily: BimblyticsFamily?
    @State private var availableBabies: [BabySyncPayload] = []
    @State private var selectedBabyIds = Set<UUID>()
    @State private var hasLoadedBabies = false
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var hasScannedToken = false

    var body: some View {
        Group {
            if let joinedFamily, hasLoadedBabies, !isLoading {
                selectionForm(for: joinedFamily)
            } else {
                scannerContent
            }
        }
        .background(AppColors.background)
        .navigationTitle(joinedFamily == nil ? "Join a family" : "Select babies")
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
        }
        .task {
            if let initialToken {
                acceptInvitation(initialToken)
            }
        }
    }

    private var scannerContent: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView("Joining family...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if joinedFamily != nil {
                ContentUnavailableView(
                    "Could not load babies",
                    systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90",
                    description: Text(errorMessage ?? "Try loading the family data again.")
                )
            } else {
                QRCodeScannerView(
                    onCodeScanned: handleScannedValue,
                    onError: { errorMessage = $0 }
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.8), lineWidth: 2)
                        .padding(48)
                }

                Text("Point the camera at a Bimblytics family invitation QR code.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let displayedError = errorMessage, joinedFamily == nil {
                Text(displayedError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)

                if hasScannedToken {
                    Button("Scan another code") {
                        hasScannedToken = false
                        errorMessage = nil
                    }
                    .buttonStyle(.bordered)
                }
            }

            if joinedFamily != nil && !isLoading {
                Button("Try loading babies again") {
                    Task {
                        await loadAvailableBabies()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private func selectionForm(for family: BimblyticsFamily) -> some View {
        Form {
            Section {
                Text(family.name)
                    .font(.headline)
            } header: {
                Text("Joined family")
            }

            Section {
                if availableBabies.isEmpty {
                    Text("There are no babies in this family yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableBabies) { baby in
                        Button {
                            toggleSelection(for: baby.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(baby.name)
                                        .foregroundStyle(.primary)
                                    if let birthDate = baby.birthDate {
                                        Text("Born \(birthDate)")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
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
                Text("Sync on this device")
            } footer: {
                Text("All babies are selected by default. Deselect any you do not want stored locally.")
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
        .overlay {
            if isSaving {
                ProgressView("Saving family...")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await saveSelection()
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
                .accessibilityLabel("Save synced babies")
                .disabled(isSaving)
            }
        }
    }

    private func handleScannedValue(_ value: String) {
        if let url = URL(string: value),
           let token = AppEnvironment.familyInvitationToken(from: url) {
            acceptInvitation(token)
        } else {
            acceptInvitation(value)
        }
    }

    private func acceptInvitation(_ token: String) {
        guard !hasScannedToken else {
            return
        }

        hasScannedToken = true
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let accessToken = try await authenticationService.validAccessToken()
                joinedFamily = try await familyService.acceptInvitation(
                    token: token,
                    accessToken: accessToken
                )
                await loadAvailableBabies()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadAvailableBabies() async {
        guard let joinedFamily else {
            return
        }

        isLoading = true
        hasLoadedBabies = false
        errorMessage = nil

        do {
            let accessToken = try await authenticationService.validAccessToken()
            let deviceId = try await deviceService.registerDevice(accessToken: accessToken)
            let bootstrap = try await syncService.bootstrap(deviceId: deviceId, accessToken: accessToken)
            let familyId = joinedFamily.id

            availableBabies = bootstrap.babies
                .filter { $0.familyId.uuidString.caseInsensitiveCompare(familyId) == .orderedSame }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            selectedBabyIds = Set(availableBabies.map(\.id))
            hasLoadedBabies = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func toggleSelection(for babyId: UUID) {
        if selectedBabyIds.contains(babyId) {
            selectedBabyIds.remove(babyId)
        } else {
            selectedBabyIds.insert(babyId)
        }
    }

    private func saveSelection() async {
        guard let joinedFamily else {
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            for payload in availableBabies where selectedBabyIds.contains(payload.id) {
                try upsertBaby(payload, familyId: joinedFamily.id)
            }

            let localStore = SyncedFamilyLocalStore(modelContext: modelContext)
            try localStore.saveFamily(joinedFamily, linkedBabyIds: selectedBabyIds)

            let accessToken = try await authenticationService.validAccessToken()
            try await familyService.loadFamilies(accessToken: accessToken)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    private func upsertBaby(_ payload: BabySyncPayload, familyId: String) throws {
        let babyId = payload.id
        let descriptor = FetchDescriptor<Baby>(
            predicate: #Predicate { $0.id == babyId }
        )
        let gender: Gender = payload.genderCode?.uppercased() == "F" ? .female : .male
        let birthDate = payload.birthDate.flatMap(DateOnlyFormatter.date(from:)) ?? .now

        if let existingBaby = try modelContext.fetch(descriptor).first {
            existingBaby.familyId = familyId
            existingBaby.name = payload.name
            existingBaby.birthDate = birthDate
            existingBaby.gender = gender
        } else {
            modelContext.insert(Baby(
                id: payload.id,
                familyId: familyId,
                name: payload.name,
                birthDate: birthDate,
                gender: gender,
                diaperEnabled: true
            ))
        }
    }
}

private struct QRCodeScannerView: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> QRCodeScannerController {
        QRCodeScannerController(onCodeScanned: onCodeScanned, onError: onError)
    }

    func updateUIViewController(_ uiViewController: QRCodeScannerController, context: Context) {
    }
}

private final class QRCodeScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let onCodeScanned: (String) -> Void
    private let onError: (String) -> Void
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasReportedCode = false

    init(onCodeScanned: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        self.onCodeScanned = onCodeScanned
        self.onError = onError
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        requestCameraAccess()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession.stopRunning()
    }

    private func requestCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureCaptureSession()
                    } else {
                        self?.onError("Camera access is required to scan a family invitation.")
                    }
                }
            }
        default:
            onError("Enable camera access in Settings to scan a family invitation.")
        }
    }

    private func configureCaptureSession() {
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              captureSession.canAddInput(input) else {
            onError("A camera is not available on this device.")
            return
        }

        captureSession.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(output) else {
            onError("QR scanning is not available on this device.")
            return
        }

        captureSession.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
        self.previewLayer = previewLayer
        previewLayer.frame = view.bounds

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasReportedCode,
              let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = metadataObject.stringValue else {
            return
        }

        hasReportedCode = true
        captureSession.stopRunning()
        onCodeScanned(value)
    }
}
