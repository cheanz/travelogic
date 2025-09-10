//
//  ContentView.swift
//  travelogic
//
//  Created by admin on 9/3/25.
//

import SwiftUI
import SwiftData
import MapKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var locationManager = LocationManager()
    @StateObject private var searchService: SearchService
    @StateObject private var routeService: RouteService
    
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showingRouteSheet = false
    @State private var selectedPOIs: [PointOfInterest] = []
    @State private var searchResults: [PointOfInterest] = []
    
    init() {
        let schema = Schema([
            PointOfInterest.self,
            RouteWaypoint.self,
            SavedRoute.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        let container = try! ModelContainer(for: schema, configurations: [modelConfiguration])
        let context = ModelContext(container)
        
        self._searchService = StateObject(wrappedValue: SearchService(modelContext: context))
        self._routeService = StateObject(wrappedValue: RouteService(modelContext: context))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            mapView
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Map")
                }
                .tag(0)
            
            searchView
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .tag(1)
            
            routesView
                .tabItem {
                    Image(systemName: "route")
                    Text("Routes")
                }
                .tag(2)
        }
        .onAppear {
            locationManager.requestLocationPermission()
            updateMapRegion()
        }
        .onChange(of: locationManager.location) { _, newLocation in
            if let location = newLocation {
                mapRegion.center = location.coordinate
            }
        }
    }
    
    private var mapView: some View {
        ZStack {
            MapView(
                region: $mapRegion,
                annotations: .constant(searchResults + selectedPOIs),
                route: $routeService.currentRoute,
                is3DEnabled: true
            ) { poi in
                handlePOITap(poi)
            }
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    searchBar
                    Spacer()
                    mapControls
                }
                .padding()
                
                Spacer()
                
                if !selectedPOIs.isEmpty {
                    routeControlsBar
                }
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            TextField("Search places...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit {
                    performSearch()
                }
            
            Button(action: performSearch) {
                Image(systemName: "magnifyingglass")
            }
            .disabled(searchText.isEmpty || isSearching)
        }
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(10)
    }
    
    private var mapControls: some View {
        VStack(spacing: 10) {
            Button(action: centerOnUserLocation) {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(radius: 3)
            }
            
            Button(action: clearSelections) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(radius: 3)
            }
        }
    }
    
    private var routeControlsBar: some View {
        HStack {
            Text("\(selectedPOIs.count) selected")
                .padding(.horizontal)
            
            Spacer()
            
            Button("Optimize Route") {
                optimizeRoute()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedPOIs.count < 2)
            
            Button("Save Route") {
                showingRouteSheet = true
            }
            .buttonStyle(.bordered)
            .disabled(selectedPOIs.isEmpty)
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(15)
        .padding(.horizontal)
        .padding(.bottom)
        .sheet(isPresented: $showingRouteSheet) {
            SaveRouteSheet(
                selectedPOIs: selectedPOIs,
                routeService: routeService
            )
        }
    }
    
    private var searchView: some View {
        NavigationView {
            VStack {
                SearchTextField(searchText: $searchText, onSearch: performSearch)
                    .padding()
                
                CategoryScrollView { category in
                    searchByCategory(category)
                }
                
                if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(searchResults) { poi in
                        POIListRow(
                            poi: poi,
                            isSelected: selectedPOIs.contains { $0.id == poi.id }
                        ) {
                            togglePOISelection(poi)
                        }
                    }
                }
            }
            .navigationTitle("Search Places")
        }
    }
    
    private var routesView: some View {
        NavigationView {
            List {
                Section("Current Route") {
                    if !selectedPOIs.isEmpty {
                        ForEach(selectedPOIs.indices, id: \.self) { index in
                            POIListRow(poi: selectedPOIs[index], isSelected: true) {
                                selectedPOIs.remove(at: index)
                            }
                        }
                    } else {
                        Text("No route selected")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Saved Routes") {
                    ForEach(routeService.savedRoutes) { route in
                        SavedRouteRow(route: route) {
                            loadSavedRoute(route)
                        }
                    }
                    .onDelete(perform: deleteSavedRoute)
                }
            }
            .navigationTitle("Routes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty,
              let location = locationManager.location else { return }
        
        isSearching = true
        
        Task {
            await searchService.searchPointsOfInterest(
                query: searchText,
                near: location
            )
            
            await MainActor.run {
                searchResults = searchService.searchResults
                isSearching = false
            }
        }
    }
    
    private func searchByCategory(_ category: String) {
        guard let location = locationManager.location else { return }
        
        isSearching = true
        
        Task {
            await searchService.searchByCategory(category, near: location)
            
            await MainActor.run {
                searchResults = searchService.searchResults
                isSearching = false
            }
        }
    }
    
    private func handlePOITap(_ poi: PointOfInterest) {
        togglePOISelection(poi)
    }
    
    private func togglePOISelection(_ poi: PointOfInterest) {
        if let index = selectedPOIs.firstIndex(where: { $0.id == poi.id }) {
            selectedPOIs.remove(at: index)
        } else {
            selectedPOIs.append(poi)
        }
    }
    
    private func optimizeRoute() {
        guard selectedPOIs.count >= 2 else { return }
        
        let coordinates = selectedPOIs.map { $0.coordinate }
        
        Task {
            await routeService.calculateOptimizedRoute(waypoints: coordinates)
        }
    }
    
    private func centerOnUserLocation() {
        guard let location = locationManager.location else { return }
        
        withAnimation {
            mapRegion.center = location.coordinate
        }
    }
    
    private func clearSelections() {
        selectedPOIs.removeAll()
        searchResults.removeAll()
        routeService.currentRoute = nil
    }
    
    private func loadSavedRoute(_ route: SavedRoute) {
        routeService.loadRoute(route)
        selectedPOIs = route.waypoints.sorted { $0.order < $1.order }.compactMap { waypoint in
            PointOfInterest(
                name: waypoint.name,
                category: "Saved",
                latitude: waypoint.latitude,
                longitude: waypoint.longitude
            )
        }
        selectedTab = 0
    }
    
    private func deleteSavedRoute(offsets: IndexSet) {
        for index in offsets {
            routeService.deleteSavedRoute(routeService.savedRoutes[index])
        }
    }
    
    private func updateMapRegion() {
        if let location = locationManager.location {
            mapRegion.center = location.coordinate
        }
    }
}

struct SearchTextField: View {
    @Binding var searchText: String
    let onSearch: () -> Void
    
    var body: some View {
        HStack {
            TextField("Search for places...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit(onSearch)
            
            Button("Search", action: onSearch)
                .buttonStyle(.borderedProminent)
                .disabled(searchText.isEmpty)
        }
    }
}

struct CategoryScrollView: View {
    let onCategoryTap: (String) -> Void
    
    private let categories = [
        ("🍽️", "Restaurant"),
        ("🏨", "Hotel"),
        ("⛽", "Gas Station"),
        ("🎯", "Tourist Attraction"),
        ("🛍️", "Shopping"),
        ("🏥", "Hospital"),
        ("🏦", "Bank"),
        ("☕", "Coffee")
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                ForEach(categories, id: \.1) { emoji, category in
                    VStack {
                        Text(emoji)
                            .font(.largeTitle)
                        Text(category)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .onTapGesture {
                        onCategoryTap(category)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct POIListRow: View {
    let poi: PointOfInterest
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(poi.name)
                    .font(.headline)
                
                Text(poi.address)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(poi.category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(5)
            }
            
            Spacer()
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                .foregroundColor(isSelected ? .green : .blue)
                .font(.title2)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

struct SavedRouteRow: View {
    let route: SavedRoute
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(route.name)
                .font(.headline)
            
            HStack {
                Text("\(route.waypoints.count) stops")
                Spacer()
                Text(String(format: "%.1f km", route.totalDistance / 1000))
                Text(formatDuration(route.estimatedDuration))
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct SaveRouteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var routeName = ""
    
    let selectedPOIs: [PointOfInterest]
    let routeService: RouteService
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Route Name", text: $routeName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("This route includes \(selectedPOIs.count) stops")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Save Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        routeService.saveRoute(name: routeName.isEmpty ? "Untitled Route" : routeName)
                        dismiss()
                    }
                    .disabled(selectedPOIs.isEmpty)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
