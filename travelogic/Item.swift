//
//  Item.swift
//  travelogic
//
//  Created by admin on 9/3/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

@Model
final class PointOfInterest {
    var id: UUID
    var name: String
    var category: String
    var latitude: Double
    var longitude: Double
    var address: String
    var rating: Double
    var itemDescription: String
    var isVisited: Bool
    var createdAt: Date
    
    init(name: String, category: String, latitude: Double, longitude: Double, address: String = "", rating: Double = 0.0, description: String = "") {
        self.id = UUID()
        self.name = name
        self.category = category
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.rating = rating
        self.itemDescription = description
        self.isVisited = false
        self.createdAt = Date()
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

@Model
final class RouteWaypoint {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var name: String
    var order: Int
    var estimatedTravelTime: TimeInterval
    var distanceToNext: Double
    
    init(latitude: Double, longitude: Double, name: String, order: Int, estimatedTravelTime: TimeInterval = 0, distanceToNext: Double = 0) {
        self.id = UUID()
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.order = order
        self.estimatedTravelTime = estimatedTravelTime
        self.distanceToNext = distanceToNext
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

@Model
final class SavedRoute {
    var id: UUID
    var name: String
    var totalDistance: Double
    var estimatedDuration: TimeInterval
    var transportMode: String
    var waypoints: [RouteWaypoint]
    var createdAt: Date
    var lastModified: Date
    var isOptimized: Bool
    
    init(name: String, transportMode: String = "driving") {
        self.id = UUID()
        self.name = name
        self.totalDistance = 0
        self.estimatedDuration = 0
        self.transportMode = transportMode
        self.waypoints = []
        self.createdAt = Date()
        self.lastModified = Date()
        self.isOptimized = false
    }
}
