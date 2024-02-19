//
//  EC2ManagerApp.swift
//  EC2Manager
//
//  Created by Stormacq, Sebastien on 22/12/2023.
//

import SwiftUI

@main
struct EC2ManagerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(ViewModel())
        }
    }
}
