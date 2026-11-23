//
//  NetworkMonitor.swift
//  klymb
//
//  Network reachability observer using NWPathMonitor (PRD §F16 & Architecture §8.2).
//  Follows AGENTS.md Rules 15, 16, 18.
//

import Foundation
import Network
import Combine

@MainActor
public final class NetworkMonitor: ObservableObject {
    public static let shared = NetworkMonitor()

    @Published public var isConnected: Bool = true
    @Published public var isCellular: Bool = false
    @Published public var isExpensive: Bool = false

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "klymb.network.monitor", qos: .utility)
    private var isSimulated: Bool = false

    public init() {
        self.monitor = NWPathMonitor()
        self.monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self, !self.isSimulated else { return }
                let connected = (path.status == .satisfied)
                let cellular = path.usesInterfaceType(.cellular)
                let expensive = path.isExpensive

                if self.isConnected != connected {
                    self.isConnected = connected
                    HapticManager.selection()
                }
                self.isCellular = cellular
                self.isExpensive = expensive
            }
        }
        self.monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    /// Preview and testing helper to simulate network condition toggling
    public func setSimulatedConnected(_ connected: Bool) {
        self.isSimulated = true
        self.isConnected = connected
        HapticManager.selection()
    }

    public func resetSimulation() {
        self.isSimulated = false
        self.isConnected = (monitor.currentPath.status == .satisfied)
    }
}
