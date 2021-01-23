//
//  Helpers.swift
//  LowmadKit
//
//  Created by Johan Thorell on 2021-01-23.
//

import Foundation
import World

public struct Print {
    static func error(_ text: String) -> Void {
        print(String.error(text))
    }

    static func info(_ text: String) -> Void {
        print(String.info(text))
    }

    static func warning(_ text: String) -> Void {
        print(String.warning(text))
    }

    static func done(_ text: String) -> Void {
        print(String.done(text))
    }
}

enum BinaryOption: CaseIterable, Option {

    static let description = """

    1. Yes
    2. No

    """

    case yes
    case no

    init?(_ input: String) {
        if let option = BinaryOption.allCases.first(where: { $0.inputIsValid(input) }) {
            self = option
        } else {
            return nil
        }
    }

    func inputIsValid(_ input: String) -> Bool {
        switch self {
        case .yes:
            return ["yes", "y", "1"].contains(input.lowercased())
        case .no:
            return ["no", "n", "2"].contains(input.lowercased())
        }
    }
}

protocol Option {
    static var description: String { get }
    init?(_ input: String)
    func inputIsValid(_ input: String) -> Bool
}

struct Reader<T: Option & CaseIterable> {
    static func readLine(prompt: String) -> T {
        let optionString = Current.readLine(prompt, false, [.custom("Not a valid option, available options are: \(T.description)", { (input) -> Bool in
                return T.allCases.first(where: { $0.inputIsValid(input) }) != nil
            })],
            { (input, reason) in
                Print.error("Not a valid option, available options are: \(T.description)".bold)
            }
        )

        return T(optionString)!
    }
}

enum ReplaceOption: CaseIterable, Option {

    static let description = """

    1. Yes
    2. Yes to all
    3. No
    4. Quit

    """

    case yes
    case no
    case replaceAll
    case replaceNone

    init?(_ input: String) {
        if let option = ReplaceOption.allCases.first(where: { $0.inputIsValid(input) }) {
            self = option
        } else {
            return nil
        }
    }

    func inputIsValid(_ input: String) -> Bool {
        switch self {
        case .yes:
            return ["yes", "y", "1"].contains(input.lowercased())
        case .no:
            return ["no", "n", "3"].contains(input.lowercased())
        case .replaceAll:
            return ["2"].contains(input.lowercased())
        case .replaceNone:
            return ["q", "quit", "4"].contains(input.lowercased())
        }
    }
}

struct ReplaceOptionState {
    var replaceAll: Bool
    var replaceNone: Bool
}
