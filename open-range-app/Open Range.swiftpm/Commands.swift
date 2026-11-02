import Foundation

/// The bike's motor controller takes Modbus RTU frames over Bluetooth.
/// Register numbers and values come from the Cowboy Untamed guide:
/// https://github.com/Imaginous/Cowboy_Untamed/blob/main/IOS.md
struct Command {
    let label: String
    let data: Data

    var hex: String { data.map { String(format: "%02x", $0) }.joined() }
}

enum Modbus {
    static func crc16(_ bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for byte in bytes {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xA001 : crc >> 1
            }
        }
        return crc
    }

    /// Function 0x10: write one 16-bit register on unit 1 (the motor controller).
    static func writeRegister(_ register: UInt16, _ value: UInt16) -> Data {
        var frame: [UInt8] = [
            0x01, 0x10,
            UInt8(register >> 8), UInt8(register & 0xFF),
            0x00, 0x01,
            0x02,
            UInt8(value >> 8), UInt8(value & 0xFF)
        ]
        let crc = crc16(frame)
        frame.append(UInt8(crc & 0xFF))
        frame.append(UInt8(crc >> 8))
        return Data(frame)
    }
}

enum BikeCommands {
    static func speedLimit(on: Bool) -> Command {
        Command(label: on ? "Speed limit on" : "Speed limit off",
                data: Modbus.writeRegister(0x000B, on ? 0x0002 : 0x0001))
    }

    /// Field weakening lets the motor spin faster than 30 km/h. 0 is the factory value.
    static func fieldWeakening(percent: Int) -> Command {
        let value = UInt16((Double(percent) * 4096 / 100).rounded())
        return Command(label: "Field weakening \(percent)%",
                       data: Modbus.writeRegister(0x0081, value))
    }

    /// Without these two, changes last only until the bike is locked.
    static let saveToBike: [Command] = [
        Command(label: "Save to bike memory", data: Modbus.writeRegister(0x01FF, 0x7FFF)),
        Command(label: "Close bike memory", data: Modbus.writeRegister(0x01FF, 0x0000))
    ]
}

/// Field weakening choices. The guide's 25% "absolute maximum" is left out on purpose.
enum Boost: Int, CaseIterable, Identifiable {
    case off = 0, ten = 10, fifteen = 15, eighteen = 18, twenty = 20

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .off: return "Off (factory)"
        case .ten: return "10% – gentle"
        case .fifteen: return "15% – recommended for C3"
        case .eighteen: return "18% – recommended for C1+ / C2"
        case .twenty: return "20% – highest"
        }
    }
}
