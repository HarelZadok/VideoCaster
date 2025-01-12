//
//  Video.swift
//  VideoCaster
//
//  Created by Harel Zadok on 11/01/2025.
//

import SwiftUI

struct Video: Identifiable {
    let id: String
    let url: URL
    let creationDate: Foundation.Date?
    var thumbnail: UIImage? // Added thumbnail property
}
