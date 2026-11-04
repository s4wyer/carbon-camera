// L04, G01 — Rolls as albums: named envelopes of shots with contact sheets
// Design: darkroom palette matching the camera — charcoal canvas, tactile envelopes,
// real photograph peeking out, thin processing strip, Tear open / Open roll.

import SwiftUI
import CoreImage

struct RollsView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject private var rollStore = RollStore.shared
    @ObservedObject private var library = LibraryStore.shared
    @State private var openedRoll: Roll?
    @State private var recoveryReport: RecoveryReport?
    @State private var showRecoverySheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("Remjet").ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        // Title
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rolls")
                                .font(.system(size: 38, weight: .regular, design: .serif))
                                .foregroundColor(Color("Receipt"))
                            if let active = rollStore.activeRoll {
                                Text("Shooting · \(active.name) · \(active.frameCount) frames")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color("Receipt").opacity(0.65))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 4)
                        
                        // R11: Recovery banner — only shown when something needs attention
                        if let report = recoveryReport, report.needsUserAttention,
                           let summary = report.summary {
                            Button {
                                showRecoverySheet = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color("Safelight"))
                                    Text(summary)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color("Receipt"))
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Color("Receipt").opacity(0.65))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color("Receipt").opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color("Safelight").opacity(0.4), lineWidth: 0.5)
                                )
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 24)
                        }
                        
                        // Empty state
                        if rollStore.rolls.isEmpty {
                            emptyState
                        } else {
                            ForEach(rollStore.rolls) { roll in
                                RollEnvelopeCard(
                                    roll: roll,
                                    shots: library.shots(for: roll),
                                    isActive: roll.id == rollStore.activeRoll?.id,
                                    onOpen: { openedRoll = roll }
                                )
                                .padding(.horizontal, 24)
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                header
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await library.loadJournal()
            recoveryReport = await CaptureRecoveryAuditor.shared.audit()
        }
        .sheet(isPresented: $showRecoverySheet) {
            if let report = recoveryReport {
                RecoverySheet(report: report)
            }
        }
        .fullScreenCover(item: $openedRoll) { roll in
            RollDetailView(
                roll: roll,
                shots: library.shots(for: roll)
            )
        }
        .preferredColorScheme(.dark)
    }
    
    private var header: some View {
        HStack {
            Button {
                coordinator.navigateTo(.camera)
            } label: {
                Label("Camera", systemImage: "chevron.left")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color("Receipt"))
                    .frame(minHeight: 44)
            }
            Spacer()
            Button {
                rollStore.newRoll()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("New roll")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(Color("Brass"))
                .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
        .background(Color("Remjet"))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(Color("Receipt").opacity(0.4))
            Text("No rolls yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color("Receipt").opacity(0.65))
            Text("Load the camera and take your first frame.")
                .font(.system(size: 13))
                .foregroundColor(Color("Receipt").opacity(0.6))
                .multilineTextAlignment(.center)
            Button("Open camera") {
                coordinator.navigateTo(.camera)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Color("Remjet"))
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .background(Color("Brass"))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 24)
    }
}

// MARK: - Envelope card

private struct RollEnvelopeCard: View {
    let roll: Roll
    let shots: [Shot]
    let isActive: Bool
    let onOpen: () -> Void
    
    @State private var coverImage: UIImage?
    
    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                // Envelope top edge with routing stamp
                HStack {
                    Text(roll.state == .shooting ? "SHOOTING" : roll.state.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundColor(roll.state == .shooting ? Color("Safelight") : Color("Brass"))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(roll.state == .shooting ? Color("Safelight") : Color("Brass"), lineWidth: 1)
                        )
                    Spacer()
                    Text("\(roll.frameCount) FRAMES")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(1.0)
                        .foregroundColor(Color("Receipt").opacity(0.65))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                
                // Name + contact-sheet preview
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(roll.name)
                            .font(.system(size: 17, weight: .semibold, design: .serif))
                            .foregroundColor(Color("Receipt"))
                        Text(roll.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color("Receipt").opacity(0.65))
                    }
                    Spacer()
                    
                    // Cover photo peeking out
                    if let coverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color("Receipt").opacity(0.15)))
                            .rotationEffect(.degrees(2))
                            .offset(y: -2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                
                // Contact-sheet film strip
                if !shots.isEmpty {
                    contactStrip
                        .padding(.top, 12)
                }
                
                // Processing strip for developing rolls
                if roll.state == .developing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(Color("Safelight"))
                        Text("Processing")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color("Safelight"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                }
                
                // Open action
                HStack {
                    Spacer()
                    Text(roll.state == .ready ? "Open roll" : "View roll")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color("Brass"))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color("Brass"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("Receipt").opacity(0.06))
                    .shadow(color: Color.black.opacity(0.2), radius: 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("Receipt").opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(coverImage == nil ? "roll-without-cover-photo" : "roll-with-cover-photo")
        .task {
            if let coverID = roll.coverShotID ?? shots.first?.id,
               let shot = shots.first(where: { $0.id == coverID }) {
                coverImage = await PhotoThumbnailCache.shared.thumbnail(for: shot)
            }
        }
    }
    
    /// Horizontal negative strip of thumbnails
    private var contactStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(shots.prefix(12)) { shot in
                    FilmFrame(shot: shot)
                }
                if shots.count > 12 {
                    Text("+\(shots.count - 12)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color("Receipt").opacity(0.65))
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Single film frame thumb

private struct FilmFrame: View {
    let shot: Shot
    @State private var image: UIImage?
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color("Remjet").opacity(0.85))
                .frame(width: 40, height: 40)
            
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipped()
            }
        }
        .frame(width: 40, height: 40)
        .task {
            image = await PhotoThumbnailCache.shared.thumbnail(for: shot)
        }
    }
}

// MARK: - Roll detail (contact sheet)

struct RollDetailView: View {
    let roll: Roll
    let shots: [Shot]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedShot: Shot?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("Remjet").ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(roll.name)
                                    .font(.system(size: 28, weight: .regular, design: .serif))
                                    .foregroundColor(Color("Receipt"))
                                Text("\(roll.frameCount) frames · \(roll.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Color("Receipt").opacity(0.5))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 4),
                                GridItem(.flexible(), spacing: 4),
                                GridItem(.flexible(), spacing: 4)
                            ],
                            spacing: 4
                        ) {
                            ForEach(shots) { shot in
                                FilmContactCell(shot: shot)
                                    .onTapGesture { selectedShot = shot }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 16)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Color("Receipt"))
                }
            }
            .toolbarBackground(Color("Remjet"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .fullScreenCover(item: $selectedShot) { shot in
            PhotoDetailView(shot: shot)
        }
        .preferredColorScheme(.dark)
    }
}

private struct FilmContactCell: View {
    let shot: Shot
    @State private var image: UIImage?
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle()
                    .fill(Color("Receipt").opacity(0.08))
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .aspectRatio(1, contentMode: .fit)
        .task {
            image = await PhotoThumbnailCache.shared.thumbnail(for: shot)
        }
    }
}
// MARK: - R11 Recovery sheet

private struct RecoverySheet: View {
    let report: RecoveryReport
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if !report.recoverable.isEmpty {
                    Section {
                        ForEach(report.recoverable) { rec in
                            recoveryRow(rec)
                        }
                        .listRowBackground(Color("Receipt").opacity(0.06))
                    } header: {
                        Text("Recovered — \(report.recoverable.count) photo\(report.recoverable.count == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color("Brass"))
                    }
                }
                
                if !report.interrupted.isEmpty {
                    Section {
                        ForEach(report.interrupted) { rec in
                            recoveryRow(rec)
                        }
                        .listRowBackground(Color("Receipt").opacity(0.06))
                    } header: {
                        Text("Interrupted — tap to finish")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color("Safelight"))
                    }
                }
                
                if !report.damaged.isEmpty || !report.missing.isEmpty {
                    Section {
                        ForEach(report.damaged + report.missing) { rec in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color("Safelight"))
                                    Text(rec.captureID.prefix(8) + "…")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(Color("Receipt").opacity(0.65))
                                    Spacer()
                                    Text(rec.state.displayName)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(Color("Safelight"))
                                }
                                Text(rec.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Color("Receipt").opacity(0.6))
                            }
                        }
                        .listRowBackground(Color("Receipt").opacity(0.06))
                    } header: {
                        Text("Unrecoverable")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color("Safelight"))
                    } footer: {
                        Text("Originals were lost or corrupted by the system or another app. We kept the journal record for your records.")
                            .font(.caption2)
                            .foregroundColor(Color("Receipt").opacity(0.65))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color("Remjet"))
            .navigationTitle("Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .toolbarBackground(Color("Remjet"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(Color("Brass"))
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }
    
    @ViewBuilder
    private func recoveryRow(_ rec: RecoveryRecord) -> some View {
        HStack {
            Image(systemName: rec.state == .intact ? "checkmark.seal" : "checkmark.seal.fill")
                .font(.system(size: 12))
                .foregroundColor(Color("Brass"))
            VStack(alignment: .leading, spacing: 2) {
                Text(rec.captureID.prefix(8) + "…")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color("Receipt"))
                Text(rec.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color("Receipt").opacity(0.65))
            }
            Spacer()
            Text(rec.state.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color("Receipt").opacity(0.65))
        }
    }
}
