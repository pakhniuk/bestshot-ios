//
//  ContentView.swift
//  BestShot
//

import Photos
import SwiftUI

struct ContentView: View {
    @State private var authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var photoCount: Int?
    @State private var recentPhotos: [PHAsset] = []
    @State private var isLoadingPhotos = false

    private let imageManager = PHCachingImageManager()
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]
    private let thumbnailSize = CGSize(width: 300, height: 300)

    private var hasAccess: Bool {
        switch authorizationStatus {
        case .authorized, .limited:
            true
        default:
            false
        }
    }

    var body: some View {
        Group {
            if hasAccess {
                photoLibraryView
            } else {
                permissionView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            refreshAuthorization()
            if hasAccess {
                loadPhotos()
            }
        }
        .onChange(of: authorizationStatus) { _, newStatus in
            if newStatus == .authorized || newStatus == .limited {
                loadPhotos()
            }
        }
        .onDisappear {
            imageManager.stopCachingImagesForAllAssets()
        }
    }

    private var permissionView: some View {
        VStack(spacing: 16) {
            Text("BestShot")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("We need access to your photos.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Grant Access", action: grantAccess)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var photoLibraryView: some View {
        VStack(spacing: 0) {
            Text("You have \(photoCount ?? 0) photos")
                .font(.title2)
                .padding()

            if isLoadingPhotos {
                Spacer()
                ProgressView("Loading photos...")
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(recentPhotos, id: \.localIdentifier) { asset in
                            PhotoThumbnail(
                                asset: asset,
                                imageManager: imageManager,
                                targetSize: thumbnailSize
                            )
                        }
                    }
                    .padding(2)
                }
            }
        }
    }

    private func refreshAuthorization() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    private func grantAccess() {
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

    private func loadPhotos() {
        isLoadingPhotos = true

        Task {
            async let totalCount = countAllPhotos()
            async let recent = fetchRecentPhotos()

            let (count, assets) = await (totalCount, recent)
            photoCount = count
            recentPhotos = assets
            isLoadingPhotos = false

            imageManager.startCachingImages(
                for: assets,
                targetSize: thumbnailSize,
                contentMode: .aspectFill,
                options: nil
            )
        }
    }

    private func countAllPhotos() async -> Int {
        await Task.detached {
            PHAsset.fetchAssets(with: .image, options: nil).count
        }.value
    }

    private func fetchRecentPhotos() async -> [PHAsset] {
        await Task.detached {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.fetchLimit = 100

            let result = PHAsset.fetchAssets(with: .image, options: options)
            var assets: [PHAsset] = []
            assets.reserveCapacity(result.count)
            result.enumerateObjects { asset, _, _ in
                assets.append(asset)
            }
            return assets
        }.value
    }
}

private struct PhotoThumbnail: View {
    let asset: PHAsset
    let imageManager: PHCachingImageManager
    let targetSize: CGSize

    @State private var image: UIImage?

    var body: some View {
        Color.gray.opacity(0.2)
            .aspectRatio(1, contentMode: .fill)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .onAppear(perform: loadThumbnail)
    }

    private func loadThumbnail() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { uiImage, _ in
            guard let uiImage else { return }
            Task { @MainActor in
                image = uiImage
            }
        }
    }
}

#Preview {
    ContentView()
}
