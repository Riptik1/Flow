//
//  TerminalStore.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import Combine
import SwiftUI

struct TerminalTab: Identifiable {
    let id: String
    var title: String
    var lines: [TerminalLineModel]
    var currentInput: String
    var isRunning: Bool

    init(index: Int) {
        self.id           = UUID().uuidString
        self.title        = "Shell \(index)"
        self.lines        = []
        self.currentInput = ""
        self.isRunning    = false
    }
}

struct TerminalLineModel: Identifiable {
    let id   = UUID()
    let text : String
    let kind : Kind
    enum Kind { case input, output, error }
}

final class TerminalStore: ObservableObject {
    static let shared = TerminalStore(connectionService: LiveFlowConnectionService.shared)

    @Published var tabs: [TerminalTab]
    @Published var activeTabID: String
    @Published var scrollTrigger: Int = 0

    private let connectionService: FlowConnectionServicing
    private var cancellables = Set<AnyCancellable>()

    init(connectionService: FlowConnectionServicing) {
        self.connectionService = connectionService
        let first = TerminalTab(index: 1)
        tabs        = [first]
        activeTabID = first.id

        connectionService.messageStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in self?.handle(msg) }
            .store(in: &cancellables)
    }

    var activeTab: TerminalTab? { tabs.first { $0.id == activeTabID } }
    var activeLines: [TerminalLineModel] { activeTab?.lines ?? [] }

    var activeInputBinding: Binding<String> {
        Binding(
            get: { [weak self] in self?.activeTab?.currentInput ?? "" },
            set: { [weak self] val in
                guard let self,
                      let idx = self.tabs.firstIndex(where: { $0.id == self.activeTabID })
                else { return }
                self.tabs[idx].currentInput = val
            }
        )
    }

    func ensureSessionsOpen() {
        for tab in tabs where tab.lines.isEmpty {
            connectionService.send(.terminalNewSession(sessionID: tab.id))
        }
        if let first = tabs.first, first.lines.isEmpty {
            connectionService.send(.terminalNewSession(sessionID: first.id))
        }
    }

    func openSession(for tab: TerminalTab) {
        connectionService.send(.terminalNewSession(sessionID: tab.id))
    }

    func addTab() {
        let tab = TerminalTab(index: tabs.count + 1)
        tabs.append(tab)
        activeTabID = tab.id
        connectionService.send(.terminalNewSession(sessionID: tab.id))
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func closeTab(id: String) {
        connectionService.send(.terminalCloseSession(sessionID: id))
        guard tabs.count > 1 else { return }
        if activeTabID == id {
            let idx    = tabs.firstIndex(where: { $0.id == id }) ?? 0
            let newIdx = idx > 0 ? idx - 1 : 1
            activeTabID = tabs[newIdx].id
        }
        tabs.removeAll { $0.id == id }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func closeAllSessions() {
        for tab in tabs { connectionService.send(.terminalCloseSession(sessionID: tab.id)) }
    }

    func runActiveCommand() {
        guard let idx = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        let cmd = tabs[idx].currentInput.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty else { return }
        tabs[idx].lines.append(TerminalLineModel(text: cmd, kind: .input))
        tabs[idx].currentInput = ""
        tabs[idx].isRunning    = true
        connectionService.send(.terminalInput(sessionID: activeTabID, command: cmd))
        scrollTrigger += 1
    }

    private func handle(_ message: FlowMessage) {
        switch message {
        case .terminalOutput(let sid, let text):
            guard let idx = tabs.firstIndex(where: { $0.id == sid }) else { return }
            let trimmed = text.trimmingCharacters(in: .newlines)
            guard !trimmed.isEmpty else { return }
            trimmed.components(separatedBy: "\n").forEach { line in
                guard !line.isEmpty else { return }
                tabs[idx].lines.append(TerminalLineModel(text: line, kind: .output))
            }
            tabs[idx].isRunning = false
            if sid == activeTabID { scrollTrigger += 1 }

        case .terminalError(let sid, let text):
            guard let idx = tabs.firstIndex(where: { $0.id == sid }) else { return }
            let trimmed = text.trimmingCharacters(in: .newlines)
            guard !trimmed.isEmpty else { return }
            tabs[idx].lines.append(TerminalLineModel(text: trimmed, kind: .error))
            tabs[idx].isRunning = false
            if sid == activeTabID { scrollTrigger += 1 }

        default:
            break
        }
    }
}
