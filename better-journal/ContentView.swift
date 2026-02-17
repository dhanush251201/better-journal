//
//  ContentView.swift
//  better-journal
//
//  Created by Dhanush Gowdhaman on 2/11/26.
//

import SwiftUI

private let motivationalMessages: [String] = [
    "Every day is a fresh page in your story.",
    "Small steps forward are still progress.",
    "Your thoughts matter — write them down.",
    "Reflection is the beginning of growth.",
    "Be kind to yourself today.",
    "What you feel is valid and worth exploring.",
    "Progress, not perfection.",
    "Today is full of possibilities.",
    "You are stronger than you think.",
    "Take a moment to appreciate how far you've come.",
    "Your journal is a safe space — let it all out.",
    "Gratitude turns what we have into enough.",
    "One mindful moment can change your whole day.",
    "Writing is thinking on paper.",
    "You don't have to have it all figured out.",
    "The best time to start is now.",
    "Every entry is a gift to your future self.",
]

struct ContentView: View {
    @State private var store = JournalStore()
    @State private var showingNewEntry = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                carouselView
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                if store.entries.isEmpty {
                    emptyState
                        .frame(maxHeight: .infinity)
                } else {
                    entryList
                }
            }
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewEntry = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingNewEntry) {
                EntryEditorView(store: store)
            }
        }
    }

    private var dailyMessage: String {
        let dayIndex = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return motivationalMessages[dayIndex % motivationalMessages.count]
    }

    private var carouselView: some View {
        let current = store.currentStreak
        let longest = store.longestStreak

        return TabView {
            // Slide 1: Daily motivational message
            VStack(spacing: 10) {
                Image(systemName: "sun.max.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text(dailyMessage)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 16)

            // Slide 2: AI Insight
            if let insight = store.journalInsight {
                VStack(spacing: 10) {
                    Image(systemName: "brain.head.profile.fill")
                        .font(.title2)
                        .foregroundStyle(.purple)
                    Text(insight)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(4)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
                .padding(.horizontal, 16)
            }

            // Slide 3: Streak insights
            HStack(spacing: 24) {
                VStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text(verbatim: "\(current)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Current Streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 50)

                VStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                    Text(verbatim: "\(longest)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Longest Streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 16)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 160)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No Entries Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Tap the pencil icon to write your first entry.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var entryList: some View {
        List {
            ForEach(store.entries) { entry in
                NavigationLink(destination: EntryEditorView(store: store, entry: entry)) {
                    EntryRowView(entry: entry)
                }
            }
            .onDelete(perform: store.delete)
        }
        .listStyle(.insetGrouped)
    }
}

struct EntryRowView: View {
    let entry: JournalEntry

    private var formattedDate: String {
        entry.date.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let collage = entry.collage, !collage.isEmpty {
                CollageDisplayView(collageData: collage, height: 120)
            }
            HStack {
                Text(entry.title.isEmpty ? "Untitled" : entry.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !entry.content.isEmpty {
                Text(entry.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let sentiment = entry.sentiment {
                SentimentTagView(sentiment: sentiment)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
