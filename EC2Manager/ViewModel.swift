//
//  ViewModel.swift
//  EC2Manager
//
//  Created by Stormacq, Sebastien on 24/12/2023.
//

import Foundation
import SwiftUI
import Amplify

@MainActor
final class ViewModel: ObservableObject {
        
    enum AppState: Equatable {
        static func == (lhs: ViewModel.AppState, rhs: ViewModel.AppState) -> Bool {
            switch (lhs, rhs) {
            case (let .error(title1, message1, _), let .error(title2, message2, _)):
                return title1 == title2 && message1 == message2

            case (.noData, .noData): return true
            case (.loading, .loading): return true
            case (.dataAvailable, .dataAvailable): return true

            default:
                return false
            }
        }
        
        case noData
        case loading
        case dataAvailable
        case error(String, String, Error?) //title, message, error
    }
    
    // Global application state
    @Published var state: AppState = .noData
    private func changeState(to newState: AppState) -> Void {
        withAnimation {
            self.state = newState
        }
    }
    
    @Published var instances: [EC2Instance]

    private let backend: Backend?
    
    public init() {
        self.instances = []
        do {
            self.backend = try Backend()
        } catch {
            self.backend = nil
            changeState(to: .error("Fatal error", "Can not create backend", error))
        }
    }
    
    func stopInstance(_ instance: EC2Instance, user: String) async -> Void {
        await callBackend { try await backend?.stopInstance(ec2: instance) }
        await pollRefresh(count: 1, maxCount: 100, instance: instance, desiredState: .stopped, user: user)
    }
    
    func startInstance(_ instance: EC2Instance, user: String) async -> Void {
        await callBackend { try await backend?.startInstance(ec2: instance) }
        await pollRefresh(count: 1, maxCount: 100, instance: instance, desiredState: .running, user: user)
    }
    
    func terminateInstance(_ instance: EC2Instance, user: String) async -> Void {
        await callBackend { try await backend?.terminateInstance(ec2: instance) }
        await pollRefresh(count: 1, maxCount: 100, instance: instance, desiredState: .terminated, user: user)
    }

    func listInstances(user: String) async -> [EC2Instance] {
        let r = await callBackend {
            // self.instance must be mutated before the global app state changes
            self.instances = try await backend?.listInstances(user: user) ?? []
            return self.instances
        }
        return r ?? []
    }
    
    // TODO: there is no need for recursivity here, it could be a simple while loop, couldn't it be ?
    func pollRefresh(count: Int, maxCount: Int, instance: EC2Instance, desiredState: EC2Instance.EC2InstanceState, user: String) async -> Void {
        
        print("pollRefresh. count = \(count). maxCount=\(maxCount). state = \(instance.localizedState)")
        
        // stop this recurdive call when the instance reaches the desired state or when we exceed the number of retries
        if (instance.state != desiredState && count <= maxCount) {
            
            // get a new list of instances and their state
            var newInstance: EC2Instance = instance
            if let instances = try? await backend?.listInstances(user: user) {
                // find the new instance to be able to pass its status
                newInstance = instances.find(id: instance.id)
                
                // refresh the UI
                Task { self.instances = instances }
            }
            
            // wait a bit
            try? await Task.sleep(seconds: 5)
            
            // check if we need a new refresh or not, with a max counter
            await pollRefresh(count: count+1, maxCount: maxCount, instance: newInstance, desiredState: desiredState, user: user)
        }
        
    }
    
    // generic function to call the Backend, this allows to have all the error handling and state management in one place
    private func callBackend<Output>(closure: () async throws -> Output?) async -> Output? {
        
        guard backend != nil else {
            return nil
        }

        var result: Output?
        do {
            changeState(to: .loading)
            result = try await closure()
            changeState(to: .dataAvailable)
        } catch BackendError.unauthorized(let msg) {
            changeState(to: .error("Unauthorized Error", msg, nil))
        } catch BackendError.invalidParameterValue(let msg) {
            changeState(to: .error("Invalid Parameter Error", msg, nil))
        } catch BackendError.serviceError(let error, let msg) {
            changeState(to: .error("Service Error", msg, error))
        } catch {
            changeState(to: .error("Unknown Error", "and unknown cause:", error))
        }
        return result

    }
    
        
    func imageFor(_ ec2: EC2Instance, for colorScheme: ColorScheme) -> URL? {
        let fileName = if ec2.os.starts(with: "Amazon Linux") { colorScheme == .dark ? "aws-dark" : "aws-light" }
        else if ec2.os.starts(with: "Ubuntu") { "ubuntu" }
        else if ec2.os.starts(with: "Windows") { "windows" }
        else if ec2.os.starts(with: "macOS") { "macos" }
        else { "linux" }
        return Bundle.main.url(forResource: fileName, withExtension: "png")
    }
    
    func instanceDescription(_ ec2: EC2Instance) async -> String {
//        return "not implemented yet"
        return (try? await backend?.describeInstance(ec2: ec2)) ?? "no description"
//        return (try? await backend?.describeInstanceWithKnowledgeBase(ec2: ec2)) ?? "no description"
    }
}

extension EC2Instance {
    var localizedState: String {
        get {
            switch self.state {
            case .running: "Running"
            case .stopped: "Stopped"
            case .terminated: "Terminated"
            case .shuttingDown: "Shutting Down"
            case .pending: "Pending"
            case .stopping: "Stopping"
            case .unknown: "Unknown"
            }
        }
    }
}

// MARK: Model data structure

extension Array<EC2Instance> {
    static let mock = [
        EC2Instance(id: "i-abcdef123456789", name: "Dev Machine", platform: "Linux/UNIX", os: "Amazon Linux", ip: "172.168.3.34", state: .running, ami: "ami-12345", type: "c7g.16xlarge"),
        EC2Instance(id: "i-987654321fedcba", name: "Blue Screen", platform: "Windows", os: "Windows", ip: "193.27.17.54", state: .stopped, ami: "ami-12345", type: "t3a.xlarge"),
        EC2Instance(id: "i-000000000000000", name: "VPN Server", platform: "Linux/UNIX", os: "Ubuntu", ip: "54.34.2.123", state: .terminated, ami: "ami-12345", type: "t4g.nano"),
        EC2Instance(id: "i-9876543210abcde", name: "Dev Server", platform: "Linux/UNIX", os: "macOS", ip: "54.147.0.194", state: .running, ami: "ami-12345", type: "mac2.metal")
    ]
}

extension Array<EC2Instance> {
    // find by instance id
    func find(id: String) -> EC2Instance {
        let instances = self.filter { $0.id == id }
        precondition(instances.count == 1, "Can not have multiple EC2 instances with the same ID")
        return instances[0]
    }
}

// Mocked EC2 Descriptiion
let mockedDescription =
"""
A powerful virtual server for demanding enterprise workloads.

- 128 vCPUs (virtual CPUs)
- 3,904 GiB of memory
- Optimized for memory-intensive applications and high performance computing
- SSD-backed ephemeral storage providing very high IOPS/throughput
"""

// Mocked User
struct MockedUser: AuthUser {
    var username: String
    var userId: String
}
extension ViewModel {
    var mockedUser: AuthUser {
        get { MockedUser(username: "mocked", userId: "1234") }
    }
}

struct EC2Instance: Hashable {
    let id: String
    let name: String
    let platform: String
    var os: String
    var ip: String
    var state: EC2InstanceState
    let ami: String
    let type: String

    enum EC2InstanceState {
        case terminated
        case stopped
        case stopping
        case running
        case shuttingDown
        case pending
        case unknown
    }
    
    public init(id: String, name: String, platform: String, os: String, ip: String, state: EC2InstanceState, ami: String, type: String) {
        self.id = id
        self.name = name
        self.platform = platform
        self.os = os
        self.ip = ip
        self.state = state
        self.ami = ami
        self.type = type
    }
    init(from instance: EC2Instance) {
        self.init(id: instance.id,
                  name: instance.name,
                  platform: instance.platform,
                  os: instance.os,
                  ip: instance.ip,
                  state: instance.state,
                  ami: instance.ami,
                  type: instance.type)
    }
}
