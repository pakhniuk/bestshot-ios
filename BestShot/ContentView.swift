//
//  ContentView.swift
//  BestShot
//

import Photos
import SwiftUI

struct ContentView: View {
    @State private var authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var photoCount: Int?

    private var hasAccess: Bool {
        switch authorizationStatus {
        case .authorized, .limited:
            true
        default:
            false
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            if hasAccess {
                Text("You have \(photoCount ?? 0) photos")
                    .font(.title2)
            } else {
                Text("BestShot")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("We need access to your photos.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Grant Access", action: grantAccess)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            refreshAuthorization()
            if hasAccess {
                countPhotos()
            }
        }
        .onChange(of: authorizationStatus) { _, newStatus in
            if newStatus == .authorized || newStatus == .limited {
                countPhotos()
            }
        }
    }

    private func refreshAuthorization() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    private func grantAccess() {
        print("Current status:", authorizationStatus)
        switch authorizationStatus {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                Task { @MainActor in
                    authorizationStatus = status
                }
            }
        case .denied, .restricted:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        default:
            break
        }
    }

    private func countPhotos() {
        Task {
            let count = PHAsset.fetchAssets(with: .image, options: nil).count
            photoCount = count
        }
    }
}

#Preview {
    ContentView()
}
