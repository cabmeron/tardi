import SwiftUI
import SwiftData
import MapKit
import CoreLocation

/// The app's primary home screen: an interactive, lo-fi real map displaying
/// custom habit nodes with custom naming, live countdown indicators,
/// dynamic departure times, and animated multi-modal routes.
struct RadarHomeView: View {
    @Query(sort: \Commitment.createdAt, order: .reverse) private var commitments: [Commitment]
    @ObservedObject private var locationManager = LocationManager.shared

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedCommitment: Commitment?
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var draft: DraftLocation?
    @State private var showingSchedule = false

    var body: some View {
        ZStack {
            LofiMapView(
                position: $cameraPosition,
                userCoordinate: locationManager.currentCoordinate,
                commitments: commitments,
                draft: $draft,
                onSelectCommitment: { commitment in
                    selectedCommitment = commitment
                },
                onTapCoordinate: { coordinate in
                    placeDraft(at: coordinate, name: nil)
                }
            )
            .ignoresSafeArea()

            // Top Floating Search Bar
            VStack {
                searchPanel
                Spacer()
            }

            // Bottom Action Bar for Draft Node Placement & Radius Sizing
            VStack {
                Spacer()
                draftActionBar
            }
        }
        .onAppear {
            locationManager.startUpdatingUserLocation()
        }
        .onDisappear {
            locationManager.stopUpdatingUserLocation()
        }
        .sheet(item: $selectedCommitment) { commitment in
            CommitmentDetailView(
                commitment: commitment,
                userCoordinate: locationManager.currentCoordinate
            )
        }
        .sheet(isPresented: $showingSchedule) {
            if let draft {
                NewCommitmentView(
                    location: PickedLocation(name: draft.name, coordinate: draft.coordinate),
                    radius: draft.radius
                ) {
                    self.draft = nil
                }
            }
        }
    }

    // MARK: - Search Interface

    private var searchPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 15, weight: .semibold))

                TextField("Search places for tardi habits...", text: $searchText)
                    .font(.system(size: 15))
                    .onSubmit(search)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.secondary.opacity(0.18), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 3)

            if !searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(searchResults.enumerated()), id: \.offset) { index, item in
                        if index > 0 {
                            Divider()
                        }
                        Button {
                            selectSearchResult(item)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundStyle(Color.accentColor)
                                    .font(.system(size: 16))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "Unknown Location")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.primary)

                                    if let address = item.placemark.title {
                                        Text(address)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.secondary.opacity(0.15), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func search() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        if let userCoord = locationManager.currentCoordinate {
            request.region = MKCoordinateRegion(
                center: userCoord,
                latitudinalMeters: 20_000,
                longitudinalMeters: 20_000
            )
        }

        MKLocalSearch(request: request).start { response, _ in
            searchResults = response?.mapItems ?? []
        }
    }

    private func selectSearchResult(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        placeDraft(at: coordinate, name: item.name ?? "Selected Location")
        searchText = ""
        searchResults = []

        withAnimation(.easeInOut(duration: 0.8)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: 900,
                    longitudinalMeters: 900
                )
            )
        }
    }

    // MARK: - Draft Node Placement & Radius Customizer

    private var draftActionBar: some View {
        Group {
            if let currentDraft = draft {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("NEW HABIT NODE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                                .tracking(1)

                            Text(currentDraft.name)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        Spacer()

                        Text("\(Int(currentDraft.radius))m")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }

                    // Interactive Radius Slider
                    VStack(spacing: 4) {
                        Slider(
                            value: Binding(
                                get: { currentDraft.radius },
                                set: { draft?.radius = $0 }
                            ),
                            in: 25...1000,
                            step: 25
                        )
                        .tint(Color.accentColor)

                        HStack {
                            Text("Tight (25m)").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text("Wide (1000m)").font(.caption2).foregroundStyle(.secondary)
                        }
                    }

                    // Quick Radius Presets
                    HStack(spacing: 8) {
                        ForEach([50.0, 100.0, 250.0, 500.0], id: \.self) { preset in
                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    draft?.radius = preset
                                }
                            } label: {
                                Text("\(Int(preset))m")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        currentDraft.radius == preset ? Color.accentColor : Color(.tertiarySystemFill),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(currentDraft.radius == preset ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Divider()
                        .padding(.vertical, 2)

                    // Action Buttons
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                draft = nil
                            }
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                                .foregroundStyle(.primary)
                        }

                        Button {
                            showingSchedule = true
                        } label: {
                            HStack(spacing: 6) {
                                Text("Set Schedule")
                                    .font(.system(size: 15, weight: .bold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentColor, in: Capsule())
                            .foregroundStyle(.white)
                        }
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: draft)
    }

    private func placeDraft(at coordinate: CLLocationCoordinate2D, name: String?) {
        draft = DraftLocation(
            coordinate: coordinate,
            radius: draft?.radius ?? 100,
            name: name ?? "Custom Location"
        )
        if name == nil {
            reverseGeocode(coordinate)
        }
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            guard let name = placemarks?.first?.name ?? placemarks?.first?.thoroughfare else { return }
            DispatchQueue.main.async {
                guard let currentDraft = draft,
                      abs(currentDraft.coordinate.latitude - coordinate.latitude) < 0.0001,
                      abs(currentDraft.coordinate.longitude - coordinate.longitude) < 0.0001 else { return }
                draft?.name = name
            }
        }
    }
}
