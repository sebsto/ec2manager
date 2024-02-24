//
//  EC2View.swift
//  EC2Manager
//
//  Created by Stormacq, Sebastien on 24/12/2023.
//

import SwiftUI
import Amplify
import Authenticator

struct EC2ListView: View {
    
    @EnvironmentObject var model: ViewModel
    let user: AuthUser
    
    @State private var showingTerminateAlert = false
    
    var body: some View {
        VStack {
            Text("My EC2 Machines").font(.headline)
            Text("built with ❤️ for \(user.username)")
            List($model.instances, id: \.self) { $instance in
                Section {
                    NavigationLink(destination: EC2DescriptionView(ec2: instance)) {
                        EC2View(ec2: instance)
                    }
                }
                .padding(.horizontal, -10)
                .swipeActions(edge: .trailing) {
                    
                    if (instance.state != .terminated) {
                        
                        Button(action: {
                            Task { await model.stopInstance(instance, user: user.username) }
                        } ) {
                            Label("Stop", systemImage: "stop.circle")
                        }
                        .tint((instance.state != .stopped ? .orange : .gray))
                        .disabled(instance.state == .stopped)
                        
                        Button(action: {
                            showingTerminateAlert = true
                        } ) {
                            Label("Terminate", systemImage: "xmark.circle")
                        }
                        // this should be always the case here (always red and enabled)
                        .tint((instance.state != .terminated ? .red : .gray))
                        .disabled(instance.state == .terminated)
                        
                        Button(action: {
                            Task { await model.startInstance(instance, user: user.username) }
                        } ) {
                            Label("Start", systemImage: "play.circle")
                        }
                        .tint((instance.state != .running ? .green : .gray))
                        .disabled(instance.state == .running)
                    }
                }
                .alert(isPresented: $showingTerminateAlert) {
                    Alert(
                        title: Text("Warning!").foregroundColor(.red),
                        message: Text("Terminating an instance can not be undone."),
                        primaryButton: .destructive(Text("Terminate")) {
                            Task { await model.terminateInstance(instance, user: user.username) }
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
            
            .refreshable {
                Task {
                    let _ = await model.listInstances(user: user.username)
                }
            }
            .padding(.horizontal, -10)
        }
    }
}

struct EC2View: View {
    
    @EnvironmentObject var model: ViewModel
    @Environment(\.colorScheme) var colorScheme

    let ec2: EC2Instance
    
    var body: some View {
        HStack {
            AsyncImage(url: model.imageFor(ec2, for: colorScheme)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
            .frame(width: 50)
            .padding(.trailing)
            
            VStack(alignment: .leading) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(ec2.name)
                            .font(.headline)
                        Text(ec2.id)
                            .font(.caption)
                    }
                    Spacer()
                    ec2.instanceStateView()
                }
                Spacer()
                HStack {
                    Text(ec2.os)
                    Spacer()
                    Text(ec2.ip)
                }
            }
        }
    }
}

extension EC2Instance {
    @ViewBuilder
    func instanceStateView(small: Bool = true) -> some View {
        let color = switch self.state {
        case .running: Color.green
        case.terminated: Color.red
        case.stopped: Color.orange
        case .stopping: Color.gray
        case .shuttingDown: Color.gray
        case .pending: Color.gray
        case .unknown: Color.black
        }
        Text(self.localizedState)
            .font(small ? .caption : .headline)
            .padding(5)
            .foregroundStyle(.white)
            .background(RoundedRectangle(cornerRadius: 4).fill(color))
    }
}

struct EC2DescriptionView: View {
    
    @EnvironmentObject var model: ViewModel
    @Environment(\.colorScheme) var colorScheme

    let ec2: EC2Instance
    @State var description : [ViewModel.InstanceDescriptionType : String] = [:]
    
    var body: some View {
        TabView {
            description(for: .api)
                .tabItem {
                    Label("API", systemImage: "doc.text")
                }
                .task {
                    // trigger description loading here
                    await loadEC2InstanceDescription(for: .api)

                }
            description(for: .llm)
                .tabItem {
                    Label("LLM", systemImage: "text.bubble")
                }
                .task {
                    // trigger description loading here
                    await loadEC2InstanceDescription(for: .llm)

                }
            description(for: .kb)
                .tabItem {
                    Label("KB", systemImage: "text.magnifyingglass")
                }
                .task {
                    // trigger description loading here
                    await loadEC2InstanceDescription(for: .kb)
                }
        }
    }

    func loadEC2InstanceDescription(for type: ViewModel.InstanceDescriptionType) async {
        if description[type] == nil {
            print("Loading \(type.rawValue) description for \(ec2.type)")
            description[type] = await model.instanceDescription(ec2, type: type)
            print(description[type]!)
        }
    }
    
    @ViewBuilder
    func description(for type: ViewModel.InstanceDescriptionType) -> some View {
        VStack {
            
            AsyncImage(url: model.imageFor(ec2, for: colorScheme)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
            .frame(width: 150)
            .padding([.top, .bottom])
            
            HStack {
                VStack(alignment: .leading) {
                    Text(ec2.name)
                        .font(.headline)
                    Text(ec2.id)
                }
                Spacer()
                ec2.instanceStateView(small: false)
            }
            .padding()
            
            Text(ec2.type)
                .font(.title)
                .padding()
            
            if let description = description[type] {
                ScrollView {
                    Text(description)
                }
                .padding()
            } else {
                Spacer()
                ProgressView {
                    Text("Loading the description")
                        .foregroundStyle(colorScheme == .dark ? .white : .gray)
                }
                Spacer()
            }
        }
    }
}


#Preview("EC2 List View") {
    let model = ViewModel()
    model.instances = [EC2Instance].mock
    return EC2ListView(user: model.mockedUser)
        .environmentObject(model)
}

#Preview("EC2 View") {
    let model = ViewModel()
    model.instances = [EC2Instance].mock
    return EC2View(ec2: model.instances[0])
        .frame(height: 50)
        .environmentObject(model)
}

#Preview("EC2 Description View") {
    let model = ViewModel()
    model.instances = [EC2Instance].mock
    return EC2DescriptionView(ec2: model.instances[0], description: mockedDescription)
        .environmentObject(model)
}

#Preview("EC2 Description View Loading") {
    let model = ViewModel()
    model.instances = [EC2Instance].mock
    return EC2DescriptionView(ec2: model.instances[0])
        .environmentObject(model)
}

