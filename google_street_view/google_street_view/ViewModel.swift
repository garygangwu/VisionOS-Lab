import SwiftUI
import RealityKit
import Observation
import Foundation

struct Config {
    static var apiKey: String {
        let path = Bundle.main.path(forResource: "Config", ofType: "plist")
            ?? Bundle.main.path(forResource: "Config.sample", ofType: "plist")
            ?? { fatalError("Missing Config.plist file") }()

        guard let dict = NSDictionary(contentsOfFile: path),
              let key = dict["API_KEY"] as? String else {
            fatalError("Missing API_KEY")
        }
        return key
    }
}


@MainActor
@Observable
class ViewModel {

    private var contentEntity = Entity()

    // Current GPS coordinates (Downtown SF - Market St & 4th St)
    var latitude: Double = 37.7855
    var longitude: Double = -122.4056

    // Movement distance in degrees (approximately 10 meters)
    private let moveDistance: Double = 0.0001

    // Loading state to prevent multiple simultaneous requests
    var isLoading: Bool = false

    // Current address
    var currentAddress: String = "Market St & 4th St, San Francisco, CA"
    func setupContentEntity() -> Entity {
        // SIMPLE TEST: Just create a basic blue sphere to verify rendering works
        //createSimpleBlueSphere()

        // COMMENTED OUT: Full Street View implementation

        // Only load Street View if we don't already have content
        // (e.g., when coming from address search, content is already loaded)
        if contentEntity.children.isEmpty {
            print("📍 setupContentEntity: Loading Street View for coordinates: \(latitude), \(longitude)")
            Task {
                await loadStreetView()
            }
        } else {
            print("📍 setupContentEntity: Content already loaded, skipping loadStreetView()")
        }

        return contentEntity
    }

    private func createSimpleBlueSphere() {
        print("🔵 Creating simple blue sphere for testing...")

        // Create a simple sphere mesh - SMALLER radius so it's easier to see
        let sphereMesh = MeshResource.generateSphere(radius: 1.0)

        // Create a bright blue material
        var material = SimpleMaterial()
        material.color = .init(tint: .blue)
        material.metallic = .init(floatLiteral: 0.0)
        material.roughness = .init(floatLiteral: 1.0)

        // Create the sphere entity
        let sphereEntity = ModelEntity(mesh: sphereMesh, materials: [material])

        // Position it 5 meters in front of the user
        sphereEntity.position = [0, 0, 0]

        contentEntity.addChild(sphereEntity)

        print("🔵 Blue sphere added at position: \(sphereEntity.position)")
        print("🔵 You should see a blue sphere in front of you!")
    }

    private func loadStreetView() async {
        isLoading = true
        defer { isLoading = false }

        // Download multiple Street View images from different headings to create 360° view
        print("🔄 Downloading multiple Street View images for 360° panorama...")

        // Get 4 images with 120° FOV and taller aspect ratio to cover full cylinder
        let headings = [0, 90, 180, 270]
        var images: [UIImage] = []

        for heading in headings {
            // Use 640x640 square images for better coverage
            // Use FOV=120 for wider coverage and better overlap
            let urlString = "https://maps.googleapis.com/maps/api/streetview?size=640x640&location=\(latitude),\(longitude)&fov=120&heading=\(heading)&pitch=0&key=\(Config.apiKey)"

            guard let url = URL(string: urlString) else { continue }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    images.append(uiImage)
                    print("✅ Downloaded image for heading \(heading)° (\(images.count)/4)")
                }
            } catch {
                print("❌ Failed to download image for heading \(heading)°: \(error)")
            }
        }

        if images.count == 4 {
            print("✅ All 4 images downloaded, stitching into panorama...")
            await stitchAndDisplay360Panorama(images: images)
        } else {
            print("❌ Could not download all images, falling back to single image")
            let urlString = "https://maps.googleapis.com/maps/api/streetview?size=4096x2048&location=\(latitude),\(longitude)&fov=120&pitch=0&key=\(Config.apiKey)"
            await downloadAndDisplayStreetView(urlString: urlString)
        }
    }

    private func stitchAndDisplay360Panorama(images: [UIImage]) async {
        // Create a panorama by stitching 4 square images horizontally
        // Each image is 640x640
        let imageWidth = 640
        let imageHeight = 640
        let overlap = 100  // Overlap to ensure no black gaps with 120° FOV
        let width = (imageWidth * 4) - (overlap * 3)  // Account for overlaps
        let height = imageHeight

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))

        let stitchedImage = renderer.image { context in
            // Reorder images for correct placement: 0°, 270°, 180°, 90°
            // So when viewing from inside, each image has the correct neighbor
            let reorderedImages = [images[0], images[3], images[2], images[1]]  // 0°, 270°, 180°, 90°

            for (index, image) in reorderedImages.enumerated() {
                // Calculate x position with overlap
                let x = CGFloat(index * (imageWidth - overlap))

                // Flip the image horizontally (mirror it)
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: x + CGFloat(imageWidth), y: 0)
                context.cgContext.scaleBy(x: -1.0, y: 1.0)  // Flip horizontally
                image.draw(at: CGPoint(x: 0, y: 0))
                context.cgContext.restoreGState()
            }
        }

        print("✅ Stitched panorama created: \(stitchedImage.size.width)x\(stitchedImage.size.height)")

        guard let cgImage = stitchedImage.cgImage else {
            print("❌ Failed to get CGImage from stitched panorama")
            return
        }

        do {
            // Create texture from stitched panorama
            let textureResource = try TextureResource.generate(from: cgImage, options: .init(semantic: .color))
            print("✅ Created texture resource from stitched panorama")

            await displayPanoramaOnSphere(textureResource: textureResource)
        } catch {
            print("❌ Error creating texture: \(error)")
        }
    }

    private func downloadAndDisplayStreetView(urlString: String) async {
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        print("url:", url)

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            print("✅ Downloaded image data: \(data.count) bytes")

            guard let uiImage = UIImage(data: data),
                  let cgImage = uiImage.cgImage else {
                print("❌ Failed to create image from data")
                return
            }
            print("✅ Created UIImage: \(uiImage.size.width)x\(uiImage.size.height)")

            let textureResource = try TextureResource.generate(from: cgImage, options: .init(semantic: .color))
            print("✅ Created texture resource")

            await displayPanoramaOnSphere(textureResource: textureResource)
        } catch {
            print("Error loading Street View: \(error)")
        }
    }

    private func displayPanoramaOnSphere(textureResource: TextureResource) async {
        // Create a full 360° CYLINDER for the panorama to avoid vertical distortion
        var meshDescriptor = MeshDescriptor()

        // Calculate cylinder dimensions to match the panorama aspect ratio EXACTLY
        // Panorama is: width = (640 * 4) - (100 * 3) = 2260, height = 640
        let panoramaWidth: Float = 2260.0
        let panoramaHeight: Float = 640.0
        let aspectRatio = panoramaHeight / panoramaWidth  // ~0.283

        let radius: Float = 50.0  // Cylinder radius
        let circumference = 2.0 * Float.pi * radius  // ~314.16

        // Height must match the aspect ratio of the panorama
        let height: Float = circumference * aspectRatio  // 314.16 * 0.283 ≈ 89

        let segments = 100  // More segments for smoother cylinder
        let heightSegments = 20

        var positions: [SIMD3<Float>] = []
        var textureCoordinates: [SIMD2<Float>] = []
        var indices: [UInt32] = []

        // Generate cylinder vertices (full 360°)
        for i in 0...segments {
            for j in 0...heightSegments {
                // Full circle (0 to 2π)
                let angle = Float(i) / Float(segments) * 2 * .pi

                // Height from bottom to top
                let y = (Float(j) / Float(heightSegments) - 0.5) * height

                // Position on cylinder
                let x = radius * cos(angle)
                let z = radius * sin(angle)

                // Texture coordinates
                let u = 1.0 - Float(i) / Float(segments)  // Wrap around horizontally
                let v = Float(j) / Float(heightSegments)  // Fix upside-down image

                positions.append(SIMD3<Float>(x, y, z))
                textureCoordinates.append(SIMD2<Float>(u, v))
            }
        }

        // Generate cylinder indices - REVERSED winding order for inside view
        for i in 0..<segments {
            for j in 0..<heightSegments {
                let topLeft = UInt32(i * (heightSegments + 1) + j)
                let topRight = UInt32((i + 1) * (heightSegments + 1) + j)
                let bottomLeft = UInt32(i * (heightSegments + 1) + j + 1)
                let bottomRight = UInt32((i + 1) * (heightSegments + 1) + j + 1)

                // REVERSED winding order so normals point inward
                indices.append(topLeft)
                indices.append(topRight)
                indices.append(bottomLeft)

                indices.append(bottomLeft)
                indices.append(topRight)
                indices.append(bottomRight)
            }
        }

        meshDescriptor.positions = MeshBuffer(positions)
        meshDescriptor.textureCoordinates = MeshBuffer(textureCoordinates)
        meshDescriptor.primitives = .triangles(indices)
        print("✅ Created mesh descriptor with \(positions.count) vertices and \(indices.count) indices")

        do {
            let sphereMesh = try MeshResource.generate(from: [meshDescriptor])
            print("✅ Generated sphere mesh")

            // Create material with the Street View texture using SimpleMaterial
            var material = SimpleMaterial()
            material.color = .init(texture: .init(textureResource))
            material.metallic = .init(floatLiteral: 0.0)
            material.roughness = .init(floatLiteral: 1.0)
            print("✅ Created material with texture - should show Street View image")

            // Create the sphere entity
            let sphereEntity = ModelEntity(mesh: sphereMesh, materials: [material])

            // Position the sphere at the origin (user will be inside)
            sphereEntity.position = [0, 0, 0]

            // Rotate 180 degrees to correct orientation
            sphereEntity.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])

            print("✅ Created sphere entity at position: \(sphereEntity.position)")
            print("✅ ContentEntity has \(contentEntity.children.count) children before adding")

            // Add to content entity
            contentEntity.addChild(sphereEntity)

            print("✅ ContentEntity now has \(contentEntity.children.count) children")
            print("✅ 360° panorama loaded successfully - sphere should be visible!")

        } catch {
            print("Error creating sphere: \(error)")
        }
    }

    // MARK: - Navigation Methods

    func moveForward() {
        guard !isLoading else {
            print("⏳ Already loading, please wait...")
            return
        }
        latitude -= moveDistance
        print("📍 Moving forward to: \(latitude), \(longitude)")
        reloadStreetView()
    }

    func moveBackward() {
        guard !isLoading else {
            print("⏳ Already loading, please wait...")
            return
        }
        latitude += moveDistance
        print("📍 Moving backward to: \(latitude), \(longitude)")
        reloadStreetView()
    }

    func moveLeft() {
        guard !isLoading else {
            print("⏳ Already loading, please wait...")
            return
        }
        longitude -= moveDistance
        print("📍 Moving left to: \(latitude), \(longitude)")
        reloadStreetView()
    }

    func moveRight() {
        guard !isLoading else {
            print("⏳ Already loading, please wait...")
            return
        }
        longitude += moveDistance
        print("📍 Moving right to: \(latitude), \(longitude)")
        reloadStreetView()
    }

    private func reloadStreetView() {
        print("🔄 Reloading Street View...")

        // Reload with new coordinates - don't clear yet
        Task {
            print("🚀 Starting loadStreetView task...")
            await loadStreetView()

            // Only clear old content AFTER new content is ready
            print("🗑️ Clearing old panorama...")
            if contentEntity.children.count > 1 {
                let oldChild = contentEntity.children.first
                oldChild?.removeFromParent()
            }
        }
    }

    // MARK: - Address Search

    func searchAddress(_ address: String) async {
        guard !isLoading else {
            print("⏳ Already loading, please wait...")
            return
        }

        print("🔍 Searching for address: \(address)")
        isLoading = true
        defer { isLoading = false }

        // Use Google Geocoding API to convert address to coordinates
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let geocodeURL = "https://maps.googleapis.com/maps/api/geocode/json?address=\(encodedAddress)&key=\(Config.apiKey)"

        guard let url = URL(string: geocodeURL) else {
            print("❌ Invalid geocode URL")
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            print("geocodeURL:", url)

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               let firstResult = results.first,
               let geometry = firstResult["geometry"] as? [String: Any],
               let location = geometry["location"] as? [String: Any],
               let lat = location["lat"] as? Double,
               let lng = location["lng"] as? Double,
               let formattedAddress = firstResult["formatted_address"] as? String {

                print("✅ Found location: \(formattedAddress)")
                print("📍 Old coordinates: \(latitude), \(longitude)")
                print("📍 New coordinates: \(lat), \(lng)")

                // Update coordinates and address
                latitude = lat
                longitude = lng
                currentAddress = formattedAddress

                print("📍 Coordinates updated in ViewModel to: \(latitude), \(longitude)")

                // Clear existing content and load new location
                contentEntity.children.removeAll()
                await loadStreetView()
            } else {
                print("❌ Could not find location for address: \(address)")
            }
        } catch {
            print("❌ Error geocoding address: \(error)")
        }
    }
}
