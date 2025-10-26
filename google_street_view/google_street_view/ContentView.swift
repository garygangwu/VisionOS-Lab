import SwiftUI
import RealityKit

struct ContentView: View {

    @State var showImmersiveSpace = false
    @State var addressInput = ""
    @State var showAddressField = false
    @Environment(ViewModel.self) var viewModel

    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    var body: some View {
        VStack(spacing: 15) {
            if !showImmersiveSpace {
                // Address search when not in immersive mode
                VStack(spacing: 10) {
                    if showAddressField {
                        TextField("Enter address", text: $addressInput)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                Task {
                                    print("GARY1: Search address")
                                    await viewModel.searchAddress(addressInput)
                                    // Only open immersive space AFTER search completes
                                    showImmersiveSpace = true
                                }
                            }

                        HStack {
                            Button("Search") {
                                Task {
                                    // Wait for search to complete before opening immersive space
                                    await viewModel.searchAddress(addressInput)
                                    showImmersiveSpace = true
                                }
                            }
                            .disabled(addressInput.isEmpty || viewModel.isLoading)

                            Button("Cancel") {
                                showAddressField = false
                                addressInput = ""
                            }
                        }
                    } else {
                        Button("Enter Address") {
                            showAddressField = true
                        }

                        Text("or")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Downtown SF (Default)") {
                            showImmersiveSpace = true
                        }
                    }
                }
            }

            if showImmersiveSpace {
                VStack(spacing: 10) {
                    Text(viewModel.currentAddress)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Button("Close") {
                        showImmersiveSpace = false
                    }
                    .controlSize(.small)

                    Divider()
                        .padding(.vertical, 5)

                    Text("Navigate")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }

                    // Forward button
                    Button {
                        viewModel.moveForward()
                    } label: {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(viewModel.isLoading)
                    .controlSize(.small)

                    HStack(spacing: 12) {
                        // Left button
                        Button {
                            viewModel.moveLeft()
                        } label: {
                            Image(systemName: "arrow.left")
                        }
                        .disabled(viewModel.isLoading)
                        .controlSize(.small)

                        // Backward button
                        Button {
                            viewModel.moveBackward()
                        } label: {
                            Image(systemName: "arrow.down")
                        }
                        .disabled(viewModel.isLoading)
                        .controlSize(.small)

                        // Right button
                        Button {
                            viewModel.moveRight()
                        } label: {
                            Image(systemName: "arrow.right")
                        }
                        .disabled(viewModel.isLoading)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(20)
        .glassBackgroundEffect()
        .frame(minWidth: 200, minHeight: 150)
        .onChange(of: showImmersiveSpace) { _, newValue in
            Task {
                if newValue {
                    await openImmersiveSpace(id: "ImmersiveSpace")
                    print("openImmersiveSpace")
                } else {
                    await dismissImmersiveSpace()
                    print("dismissImmersiveSpace")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
