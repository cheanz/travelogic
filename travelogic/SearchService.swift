//
//  SearchService.swift
//  travelogic
//
//  Created by admin on 9/3/25.
//

import Foundation
import MapKit
import SwiftData

@MainActor
class SearchService: ObservableObject {
    @Published var searchResults: [PointOfInterest] = []
    @Published var isSearching: Bool = false
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func searchPointsOfInterest(query: String, near location: CLLocation, radius: Double = 10000) async {
        isSearching = true
        defer { isSearching = false }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radius,
            longitudinalMeters: radius
        )
        
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            
            let newResults = response.mapItems.compactMap { mapItem -> PointOfInterest? in
                guard let name = mapItem.name,
                      let location = mapItem.placemark.location else { return nil }
                
                let category = mapItem.pointOfInterestCategory?.rawValue ?? "Unknown"
                let address = formatAddress(from: mapItem.placemark)
                
                return PointOfInterest(
                    name: name,
                    category: category,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    address: address,
                    rating: 0.0,
                    description: ""
                )
            }
            
            searchResults = newResults
        } catch {
            print("Search failed: \(error.localizedDescription)")
            searchResults = []
        }
    }
    
    func searchByCategory(_ category: String, near location: CLLocation, radius: Double = 10000) async {
        await searchPointsOfInterest(query: category, near: location, radius: radius)
    }
    
    func savePointOfInterest(_ poi: PointOfInterest) {
        modelContext.insert(poi)
        try? modelContext.save()
    }
    
    func getSavedPointsOfInterest() -> [PointOfInterest] {
        let descriptor = FetchDescriptor<PointOfInterest>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        return components.joined(separator: ", ")
    }
}