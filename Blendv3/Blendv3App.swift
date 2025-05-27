//
//  Blendv3App.swift
//  Blendv3
//
//  Created by Chris Karani on 22/05/2025.
//

import SwiftUI

@main
struct Blendv3App: App {
    var body: some Scene {
        WindowGroup {
            BlendDashboardView()
                .environmentObject(BlendViewModel.init(signer: try! KeyPairSigner(secretSeed: "SATOWQKPSRAP7D77C6EMT65OIF543WQUOV6DJBPW4SGUNTP2XSIEVUKP")))
        }
    }
}
