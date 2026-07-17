import SwiftUI
import MapKit

struct LocationPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    let onLocationSelected: (Double, Double) -> Void
    
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456), // Default Jakarta
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    ))
    @State private var currentCenter = CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
    
    var body: some View {
        NavigationView {
            ZStack {
                Map(position: $cameraPosition)
                    .onMapCameraChange(frequency: .continuous) { context in
                        currentCenter = context.region.center
                    }
                    .edgesIgnoringSafeArea(.all)
                
                // Pin in center
                VStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                        .padding(.bottom, 20)
                }
            }
            .navigationTitle("Pilih Lokasi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Batal") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kirim") {
                        onLocationSelected(currentCenter.latitude, currentCenter.longitude)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.headline)
                }
            }
        }
    }
}
