// Preset favorites persistence layer
// Stores user favorite presets across app launches

import Foundation

/// User's favorite presets, persisted via UserDefaults.
public class PresetFavorites: ObservableObject {
    public static let shared = PresetFavorites()
    
    private let favoritesKey = "CarbonPresetFavorites"
    private(set) public var favoriteIDs: Set<String> = []
    
    private init() {
        load()
    }
    
    public func isFavorite(_ preset: PresetDefinition) -> Bool {
        favoriteIDs.contains(preset.presetID)
    }
    
    public func toggleFavorite(_ preset: PresetDefinition) {
        if favoriteIDs.contains(preset.presetID) {
            favoriteIDs.remove(preset.presetID)
        } else {
            favoriteIDs.insert(preset.presetID)
        }
        save()
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            favoriteIDs = decoded
        }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(favoriteIDs) {
            UserDefaults.standard.set(encoded, forKey: favoritesKey)
        }
    }
}
