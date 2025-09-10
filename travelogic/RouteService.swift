//
//  RouteService.swift
//  travelogic
//
//  Created by admin on 9/3/25.
//

import Foundation
import MapKit
import SwiftData

@MainActor
class RouteService: ObservableObject {
    @Published var currentRoute: MKRoute?
    @Published var savedRoutes: [SavedRoute] = []
    @Published var isCalculatingRoute: Bool = false
    @Published var routeWaypoints: [RouteWaypoint] = []
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadSavedRoutes()
    }
    
    func calculateRoute(from start: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, transportType: MKDirectionsTransportType = .automobile) async {
        isCalculatingRoute = true
        defer { isCalculatingRoute = false }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = transportType
        
        do {
            let directions = MKDirections(request: request)
            let response = try await directions.calculate()
            
            if let route = response.routes.first {
                currentRoute = route
            }
        } catch {
            print("Route calculation failed: \(error.localizedDescription)")
        }
    }
    
    func calculateOptimizedRoute(waypoints: [CLLocationCoordinate2D], transportType: MKDirectionsTransportType = .automobile) async {
        guard waypoints.count >= 2 else { return }
        
        isCalculatingRoute = true
        defer { isCalculatingRoute = false }
        
        let optimizedOrder = optimizeWaypointOrder(waypoints)
        var totalDistance: Double = 0
        var totalTime: TimeInterval = 0
        var routeWaypoints: [RouteWaypoint] = []
        
        for i in 0..<optimizedOrder.count {
            let waypoint = RouteWaypoint(
                latitude: optimizedOrder[i].latitude,
                longitude: optimizedOrder[i].longitude,
                name: "Waypoint \(i + 1)",
                order: i
            )
            
            if i < optimizedOrder.count - 1 {
                let nextCoordinate = optimizedOrder[i + 1]
                let request = MKDirections.Request()
                request.source = MKMapItem(placemark: MKPlacemark(coordinate: optimizedOrder[i]))
                request.destination = MKMapItem(placemark: MKPlacemark(coordinate: nextCoordinate))
                request.transportType = transportType
                
                do {
                    let directions = MKDirections(request: request)
                    let response = try await directions.calculate()
                    
                    if let route = response.routes.first {
                        waypoint.estimatedTravelTime = route.expectedTravelTime
                        waypoint.distanceToNext = route.distance
                        totalDistance += route.distance
                        totalTime += route.expectedTravelTime
                    }
                } catch {
                    print("Route segment calculation failed: \(error.localizedDescription)")
                }
            }
            
            routeWaypoints.append(waypoint)
        }
        
        self.routeWaypoints = routeWaypoints
    }
    
    func saveRoute(name: String, transportMode: String = "driving") {
        let savedRoute = SavedRoute(name: name, transportMode: transportMode)
        savedRoute.waypoints = routeWaypoints
        savedRoute.totalDistance = routeWaypoints.reduce(0) { $0 + $1.distanceToNext }
        savedRoute.estimatedDuration = routeWaypoints.reduce(0) { $0 + $1.estimatedTravelTime }
        savedRoute.isOptimized = true
        
        modelContext.insert(savedRoute)
        try? modelContext.save()
        loadSavedRoutes()
    }
    
    func loadSavedRoutes() {
        let descriptor = FetchDescriptor<SavedRoute>(sortBy: [SortDescriptor(\.lastModified, order: .reverse)])
        savedRoutes = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func deleteSavedRoute(_ route: SavedRoute) {
        modelContext.delete(route)
        try? modelContext.save()
        loadSavedRoutes()
    }
    
    func loadRoute(_ savedRoute: SavedRoute) {
        routeWaypoints = savedRoute.waypoints.sorted { $0.order < $1.order }
    }
    
    private func optimizeWaypointOrder(_ waypoints: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard waypoints.count > 2 else { return waypoints }
        
        var optimized = [waypoints.first!]
        var remaining = Array(waypoints.dropFirst().dropLast())
        let destination = waypoints.last!
        
        while !remaining.isEmpty {
            let current = optimized.last!
            let nearestIndex = remaining.enumerated().min { first, second in
                let firstDistance = distanceBetween(current, first.element)
                let secondDistance = distanceBetween(current, second.element)
                return firstDistance < secondDistance
            }?.offset ?? 0
            
            optimized.append(remaining.remove(at: nearestIndex))
        }
        
        optimized.append(destination)
        return optimized
    }
    
    private func distanceBetween(_ coord1: CLLocationCoordinate2D, _ coord2: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return location1.distance(from: location2)
    }
}