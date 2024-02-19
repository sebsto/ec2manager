//
//  ContentView.swift
//  EC2Manager
//
//  Created by Stormacq, Sebastien on 22/12/2023.
//

import SwiftUI
import Authenticator
import Amplify // for AuthUser

struct ContentView: View {
    @EnvironmentObject var model: ViewModel
    var body: some View {
        Authenticator { state in
            
            switch model.state {
            case .noData:
                VStack(alignment: .leading) {
                    Text("no data")
                        .task {
                            // trigger data loading here
                            let _ = await model.listInstances(user: state.user.username)
                        }
                    signOutView(state: state)
                }
            case .loading:
                loadingView()
                
            case .dataAvailable:
                navigationView(user: state.user)
                signOutView(state: state)

            case .error(let title, let msg, let error):
                VStack(alignment: .leading) {
                    errorView(title: title, error: error, msg: msg)
                    VStack(alignment: .center) {
                        Button("Reload") { Task { await model.listInstances(user:state.user.username)}}
                        signOutView(state: state)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func loadingView() -> some View {
        Spacer()
        ProgressView {
            Text("Loading your instances")
        }
        Spacer()
    }
    
    @ViewBuilder
    func signOutView(state: SignedInState) -> some View {
        Button("Sign out") { Task { await state.signOut() } }
    }
    
    @ViewBuilder
    func errorView(title: String, error: Error? = nil, msg: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .foregroundColor(.red)
                .font(.title)
                .padding()
            Text(msg)
                .foregroundColor(.black)
                .padding()
            
            if let error {
                VStack(alignment: .leading)  {
                    Text("Root cause:")
                        .fontWeight(.bold)
                    Text("\(error.localizedDescription)")
                }
                .padding()
            }
            Spacer()
        }
    }
    
    @ViewBuilder
    func navigationView(user: AuthUser) -> some View {
        NavigationView {
            EC2ListView(user: user)
        }
        .navigationTitle("Title")
    }
}

#Preview("Navigation View") {
    let model = ViewModel()
    model.instances = [EC2Instance].mock
    return ContentView().navigationView(user: model.mockedUser).environmentObject(model)
}

#Preview("EC2 List View") {
    let model = ViewModel()
    model.instances = [EC2Instance].mock
    return EC2ListView(user: model.mockedUser).environmentObject(model)
}

#Preview("Unauthenticated") {
    ContentView().environmentObject(ViewModel())
}

#Preview("Loading View") {
    ContentView().loadingView()
}

#Preview("Error View") {
    let error = BackendError.mock("Test Error")
    return ContentView().errorView(title: "Unauthorized", error: error, msg: "My error message")
}
