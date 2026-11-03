// L01, N02, N05, G06 — Chronological Photo Library
// Matches Screen 03 mockup pixel-for-pixel; backed by CaptureJournal (SET04)

import SwiftUI
import CoreImage

/// 03 LIBRARY: Chronological photographic grid with All, Picks, Spaces views
struct LibraryView: View {
    @ObservedObject var coordinator: AppCoordinator
    @StateObject private var store = LibraryStore()
    @State private var activeTab: LibraryTab = .all
    @State private var isSelectMode: Bool = false
    @State private var selectedShots: Set<UUID> = []
    @State private var selectedShot: Shot?
    
    enum LibraryTab: String, CaseIterable {
        case all = "All"
        case picks = "Picks"
        case spaces = "Spaces"
    }
    
    var body: some View {
        ZStack {
            // Receipt canvas background (#F6F3EC)
            Color("Receipt")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top status row: lowercase wordmark + Select action
                HStack {
                    Text("carbon")
                        .font(.system(size: 20, weight: .regular, design: .serif))
                        .foregroundColor(Color("Remjet"))
                    
                    Spacer()
                    
                    Button(isSelectMode ? "Done" : "Select") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSelectMode.toggle()
                            if !isSelectMode { selectedShots.removeAll() }
                        }
                    }
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color("Remjet"))
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 6)
                
                // Screen title: "Library" in editorial serif
                HStack {
                    Text("Library")
                        .font(.system(size: 38, weight: .regular, design: .serif))
                        .foregroundColor(Color("Remjet"))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                
                // Quiet text tabs: All / Picks / Spaces
                HStack(spacing: 28) {
                    ForEach(LibraryTab.allCases, id: \.self) { tab in
                        Button(action: { activeTab = tab }) {
                            VStack(spacing: 6) {
                                Text(tab.rawValue)
                                    .font(.system(size: 15, weight: activeTab == tab ? .semibold : .regular))
                                    .foregroundColor(Color("Remjet").opacity(activeTab == tab ? 1.0 : 0.6))
                                
                                if activeTab == tab {
                                    Rectangle()
                                        .fill(Color("CarbonInk"))
                                        .frame(height: 2)
                                } else {
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(height: 2)
                                }
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                
                // Chronological photo grid
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(filteredSections) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(section.title)
                                    .font(.system(size: 17, weight: .semibold, design: .default))
                                    .foregroundColor(Color("Remjet"))
                                    .padding(.horizontal, 24)
                                
                                let columns = [
                                    GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)
                                ]
                                
                                LazyVGrid(columns: columns, spacing: 10) {
                                    ForEach(section.shots) { shot in
                                        PhotoCard(
                                            shot: shot,
                                            isSelectMode: isSelectMode,
                                            isSelected: selectedShots.contains(shot.id),
                                            onToggleSelect: {
                                                if selectedShots.contains(shot.id) {
                                                    selectedShots.remove(shot.id)
                                                } else {
                                                    selectedShots.insert(shot.id)
                                                }
                                            },
                                            onTogglePick: {
                                                store.togglePick(shotID: shot.id)
                                            },
                                            onOpen: {
                                                selectedShot = shot
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 72)
                }
                
                // Minimal text-only bottom tab bar: Camera | Library | Lab (matches Screen 03)
                HStack(spacing: 0) {
                    bottomTabButton("Camera", active: false) {
                        coordinator.navigateTo(.camera)
                    }
                    bottomTabButton("Library", active: true) {
                        // Already on library
                    }
                    bottomTabButton("Lab", active: false) {
                        coordinator.navigateTo(.lab)
                    }
                }
                .padding(.vertical, 14)
                .background(Color("Receipt"))
                .overlay(
                    Rectangle()
                        .fill(Color("SecondaryInk").opacity(0.15))
                        .frame(height: 0.5),
                    alignment: .top
                )
            }
        }
        .task {
            await store.loadJournal()
        }
        .fullScreenCover(item: $selectedShot) { shot in
            PhotoDetailView(shot: shot)
        }
    }
    
    // MARK: - Helpers
    
    private var filteredSections: [DaySection] {
        switch activeTab {
        case .all:
            return store.sections
        case .picks:
            return store.sections.compactMap { sec in
                let picks = sec.shots.filter { store.isPick($0.id) }
                return picks.isEmpty ? nil : DaySection(title: sec.title, shots: picks)
            }
        case .spaces:
            return [] // Spaces unshared by default (P3)
        }
    }
    
    @ViewBuilder
    private func bottomTabButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: active ? .semibold : .regular))
                    .foregroundColor(Color("Remjet").opacity(active ? 1.0 : 0.55))
                
                if active {
                    Rectangle()
                        .fill(Color("Remjet"))
                        .frame(width: 40, height: 1.5)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 40, height: 1.5)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Photo Card Cell (Square 1:1, star pick indicator, select checkmark)

private struct PhotoCard: View {
    let shot: Shot
    let isSelectMode: Bool
    let isSelected: Bool
    let onToggleSelect: () -> Void
    let onTogglePick: () -> Void
    let onOpen: () -> Void
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Photo thumbnail
            GeometryReader { geo in
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                } else {
                    // Loading placeholder
                    Rectangle()
                        .fill(Color("Remjet").opacity(0.1))
                        .frame(width: geo.size.width, height: geo.size.width)
                        .overlay(
                            ProgressView()
                                .tint(Color("SecondaryInk"))
                        )
                }
            }
            .aspectRatio(1.0, contentMode: .fit)
            .cornerRadius(4)
            .task {
                thumbnail = PhotoThumbnailCache.shared.thumbnail(for: shot)
            }
            .onTapGesture {
                if !isSelectMode {
                    onOpen()
                }
            }
            
            // Star icon at top right (G06 Picks)
            Button(action: onTogglePick) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .shadow(radius: 2)
                    .padding(6)
            }
            
            // Selection indicator
            if isSelectMode {
                Button(action: onToggleSelect) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color("CarbonInk") : Color.black.opacity(0.4))
                            .frame(width: 22, height: 22)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(6)
                }
            }
        }
    }
}

// MARK: - Library Store backed by CaptureJournal

@MainActor
final class LibraryStore: ObservableObject {
    @Published var sections: [DaySection] = []
    @Published var pickIDs: Set<UUID> = []
    
    func loadJournal() async {
        do {
            let entries = try await CaptureJournal.shared.recoverAll()
            var shots: [Shot] = []
            
            for entry in entries {
                var sources: [SourceResource] = []
                if let hevc = entry.hevcFilename, let hHash = entry.hevcSHA256 {
                    sources.append(SourceResource(
                        id: UUID(),
                        captureID: entry.captureID,
                        type: .processedHEVC,
                        mediaURL: CaptureJournal.shared.fileURL(for: hevc),
                        mediaHash: hHash,
                        provenance: SourceResource.Provenance(
                            engine: "carbon-camera",
                            version: "1.0.0",
                            timestamp: entry.timestamp,
                            isUserEditable: true
                        )
                    ))
                }
                
                shots.append(Shot(
                    id: entry.id,
                    captureID: entry.captureID,
                    timestamp: entry.timestamp,
                    sources: sources,
                    currentRecipe: RecipeVersion(
                        recipeID: "natural-v1",
                        presetDefinitionID: entry.recipeVersionID,
                        engineVersion: "1.0",
                        source: .processedHEVC,
                        parameters: RecipeVersion.Parameters(
                            filmPreset: "Natural",
                            filmStrength: 0.85,
                            exposureEV: 0,
                            temperatureK: 0,
                            tintOffset: 0,
                            contrastAmount: 1,
                            saturationAmount: 1
                        )
                    ),
                    captureMetadata: Shot.CaptureMetadata(
                        temperature: 5500,
                        tint: 0,
                        iso: 100,
                        exposureDuration: .zero,
                        sceneEV: 8.0,
                        flashState: .auto,
                        lensPosition: 0.5,
                        orientation: 1
                    )
                ))
            }
            
            // Group by calendar day (Today, Yesterday, Date)
            self.sections = groupShotsByDay(shots)
        } catch {
            print("Failed to load captures: \(error)")
        }
    }
    
    func isPick(_ id: UUID) -> Bool {
        pickIDs.contains(id)
    }
    
    func togglePick(shotID: UUID) {
        if pickIDs.contains(shotID) {
            pickIDs.remove(shotID)
        } else {
            pickIDs.insert(shotID)
        }
    }
    
    private func groupShotsByDay(_ shots: [Shot]) -> [DaySection] {
        let calendar = Calendar.current
        let sorted = shots.sorted(by: { $0.timestamp > $1.timestamp })
        
        var groups: [String: [Shot]] = [:]
        var order: [String] = []
        
        for shot in sorted {
            let title: String
            if calendar.isDateInToday(shot.timestamp) {
                title = "Today"
            } else if calendar.isDateInYesterday(shot.timestamp) {
                title = "Yesterday"
            } else {
                let fmt = DateFormatter()
                fmt.dateStyle = .medium
                title = fmt.string(from: shot.timestamp)
            }
            
            if groups[title] == nil {
                groups[title] = []
                order.append(title)
            }
            groups[title]?.append(shot)
        }
        
        return order.map { DaySection(title: $0, shots: groups[$0] ?? []) }
    }
}

struct DaySection: Identifiable {
    let id = UUID()
    let title: String
    let shots: [Shot]
}
