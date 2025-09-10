//
//  MapView.swift
//  travelogic
//
//  Created by admin on 9/3/25.
//

import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var annotations: [PointOfInterest]
    @Binding var route: MKRoute?
    
    let is3DEnabled: Bool
    let onAnnotationTap: ((PointOfInterest) -> Void)?
    
    init(region: Binding<MKCoordinateRegion>, 
         annotations: Binding<[PointOfInterest]>, 
         route: Binding<MKRoute?> = .constant(nil),
         is3DEnabled: Bool = true,
         onAnnotationTap: ((PointOfInterest) -> Void)? = nil) {
        self._region = region
        self._annotations = annotations
        self._route = route
        self.is3DEnabled = is3DEnabled
        self.onAnnotationTap = onAnnotationTap
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.region = region
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        if is3DEnabled {
            mapView.mapType = .satelliteFlyover
            mapView.showsBuildings = true
            mapView.isPitchEnabled = true
            mapView.isRotateEnabled = true
            mapView.showsCompass = true
            mapView.showsScale = true
            
            let camera = MKMapCamera()
            camera.centerCoordinate = region.center
            camera.altitude = 1000
            camera.pitch = 45
            mapView.setCamera(camera, animated: false)
        } else {
            mapView.mapType = .standard
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        if mapView.region.center.latitude != region.center.latitude ||
           mapView.region.center.longitude != region.center.longitude {
            mapView.setRegion(region, animated: true)
        }
        
        updateAnnotations(mapView)
        updateRoute(mapView)
    }
    
    private func updateAnnotations(_ mapView: MKMapView) {
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        let mapAnnotations = annotations.map { poi in
            let annotation = POIAnnotation(pointOfInterest: poi)
            return annotation
        }
        
        mapView.addAnnotations(mapAnnotations)
    }
    
    private func updateRoute(_ mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)
        
        if let route = route {
            mapView.addOverlay(route.polyline)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let poiAnnotation = annotation as? POIAnnotation else {
                return nil
            }
            
            let identifier = "POIAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                annotationView?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            } else {
                annotationView?.annotation = annotation
            }
            
            annotationView?.markerTintColor = categoryColor(for: poiAnnotation.pointOfInterest.category)
            annotationView?.glyphText = categoryGlyph(for: poiAnnotation.pointOfInterest.category)
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard let poiAnnotation = view.annotation as? POIAnnotation else { return }
            parent.onAnnotationTap?(poiAnnotation.pointOfInterest)
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        private func categoryColor(for category: String) -> UIColor {
            switch category.lowercased() {
            case "restaurant", "food":
                return .systemOrange
            case "hotel", "lodging":
                return .systemPurple
            case "gas_station", "gas station":
                return .systemGreen
            case "tourist_attraction", "tourist attraction":
                return .systemRed
            case "shopping", "store":
                return .systemYellow
            default:
                return .systemBlue
            }
        }
        
        private func categoryGlyph(for category: String) -> String {
            switch category.lowercased() {
            case "restaurant", "food":
                return "🍽️"
            case "hotel", "lodging":
                return "🏨"
            case "gas_station", "gas station":
                return "⛽"
            case "tourist_attraction", "tourist attraction":
                return "🎯"
            case "shopping", "store":
                return "🛍️"
            default:
                return "📍"
            }
        }
    }
}

class POIAnnotation: NSObject, MKAnnotation {
    let pointOfInterest: PointOfInterest
    
    var coordinate: CLLocationCoordinate2D {
        return pointOfInterest.coordinate
    }
    
    var title: String? {
        return pointOfInterest.name
    }
    
    var subtitle: String? {
        return pointOfInterest.address
    }
    
    init(pointOfInterest: PointOfInterest) {
        self.pointOfInterest = pointOfInterest
    }
}