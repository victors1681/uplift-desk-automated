//
//  UpliftDesk.swift
//  uplift-desk-automated
//
//  Created by Victor Santos on 12/22/25.
//  Model representing an Uplift standing desk
//

import Foundation
import CoreBluetooth

struct UpliftDesk: Identifiable, Equatable {
    let id: UUID
    let name: String
    let rssi: Int
    weak var peripheral: CBPeripheral?

    init(peripheral: CBPeripheral, rssi: Int) {
        self.id = peripheral.identifier
        self.name = peripheral.name ?? "Unknown Desk"
        self.rssi = rssi
        self.peripheral = peripheral
    }

    static func == (lhs: UpliftDesk, rhs: UpliftDesk) -> Bool {
        lhs.id == rhs.id
    }
}
