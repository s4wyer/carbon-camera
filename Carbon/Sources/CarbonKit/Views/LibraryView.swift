import SwiftUI
import Photos

/// 03 LIBRARY: Chronological photo grid with tabs
struct LibraryView: View {
    @ObservedObject var coordinator: AppCoordinator
    @StateObject private var libraryManager = LibraryManager()
    @State private var selectedTab: Tab = .all
    @State private var isSelectMode = false
    
    enum Tab {
        case all, picks, spaces
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#FEFDFB")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Library")
                            .font(.custom("Charter", size: 32))
                            .foregroundColor(Color(hex: "#1A1614"))
                        
                        Spacer()
                        
                        Button(isSelectMode ? "Done" : "Select") {
                            isSelectMode.toggle()
                        }
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(hex: "#2C5FFF"))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    
                    // Tabs: All / Picks / Spaces
                    HStack(spacing: 24) {
                        TabButton(title: "All", isSelected: selectedTab == .all) {
                            selectedTab = .all
                        }
                        TabButton(title: "Picks", isSelected: selectedTab == .picks) {
                            selectedTab = .picks
                        }
                        TabButton(title: "Spaces", isSelected: selectedTab == .spaces) {
                            selectedTab = .spaces
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    
                    // Photo grid
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24, pinnedViews: .sectionHeaders) {
                            ForEach(libraryManager.sections) { section in
                                Section {
                                    PhotoGrid(photos: section.photos, isSelectMode: isSelectMode)
                                } header: {
                                    SectionHeader(title: section.title)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // Bottom tab bar
                VStack {
                    Spacer()
                    BottomTabBar(activeTab: .library, coordinator: coordinator)
                }
            }
        }
        .onAppear {
            libraryManager.loadPhotos()
        }
    }
}

/// Tab button for All / Picks / Spaces
private struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .medium : .regular))
                    .foregroundColor(Color(hex: "#1A1614"))
                
                if isSelected {
                    Rectangle()
                        .fill(Color(hex: "#1A1614"))
                        .frame(height: 2)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 2)
                }
            }
        }
    }
}

/// Section header (Today, Yesterday, etc.)
private struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(Color(hex: "#1A1614"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .background(Color(hex: "#FEFDFB"))
    }
}

/// Photo grid: 2 columns, variable height
private struct PhotoGrid: View {
    let photos: [LibraryPhoto]
    let isSelectMode: Bool
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(photos) { photo in
                PhotoCell(photo: photo, isSelectMode: isSelectMode)
            }
        }
    }
}

/// Individual photo cell
private struct PhotoCell: View {
    let photo: LibraryPhoto
    let isSelectMode: Bool
    @State private var isSelected = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(photo.aspectRatio, contentMode: .fit)
                .overlay(
                    // TODO: Load actual thumbnail
                    Image(systemName: "photo")
                        .foregroundColor(.gray.opacity(0.5))
                )
            
            // Star indicator (picks)
            if photo.isPick {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
                    .padding(8)
            }
            
            // Selection checkmark (select mode)
            if isSelectMode {
                Button(action: { isSelected.toggle() }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                        .padding(8)
                }
            }
        }
    }
}

/// Bottom tab bar: Camera / Library / Lab
struct BottomTabBar: View {
    enum AppTab {
        case camera, library, lab
    }
    
    let activeTab: AppTab
    let coordinator: AppCoordinator
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(title: "Camera", icon: "camera", isActive: activeTab == .camera) {
                coordinator.navigateTo(.camera)
            }
            
            TabBarButton(title: "Library", icon: "photo.on.rectangle", isActive: activeTab == .library) {
                coordinator.navigateTo(.library)
            }
            
            TabBarButton(title: "Lab", icon: "slider.horizontal.3", isActive: activeTab == .lab) {
                // TODO: Lab view
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(hex: "#FEFDFB"))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5),
            alignment: .top
        )
    }
}

private struct TabBarButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: isActive ? .medium : .regular))
                Text(title)
                    .font(.system(size: 11, weight: isActive ? .medium : .regular))
            }
            .foregroundColor(isActive ? Color(hex: "#1A1614") : Color(hex: "#8A8682"))
            .frame(maxWidth: .infinity)
        }
    }
}

/// Library manager (scaffold)
@MainActor
private class LibraryManager: ObservableObject {
    @Published var sections: [PhotoSection] = []
    
    func loadPhotos() {
        // Request Photos library access
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    self.fetchPhotos()
                }
            }
        }
    }
    
    private func fetchPhotos() {
        // Fetch Carbon photos, group by date
        // Placeholder: show empty sections
        sections = [
            PhotoSection(title: "Today", photos: []),
            PhotoSection(title: "Yesterday", photos: [])
        ]
    }
}

struct PhotoSection: Identifiable {
    let id = UUID()
    let title: String
    var photos: [LibraryPhoto]
}

struct LibraryPhoto: Identifiable {
    let id = UUID()
    let assetID: String?
    let aspectRatio: CGFloat
    let isPick: Bool
}
