//
//  ContentView.swift
//  better-journal
//
//  Created by Dhanush Gowdhaman on 2/11/26.
//

import SwiftUI

struct ContentView: View {
    @State private var store = JournalStore()
    @State private var showingNewEntry = false

    var body: some View {
        NavigationStack {
            Group {
                if store.entries.isEmpty {
                    emptyState
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
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
