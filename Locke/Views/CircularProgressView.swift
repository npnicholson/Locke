//
//  CircularProgressView.swift
//  Locke
//
//  Created by Norris Nicholson on 9/22/24.
//
// @see: https://sarunw.com/posts/swiftui-circular-progress-bar/
import SwiftUI

struct CircularProgressView: View {
    let progress: Double
    let enabled: Bool
    var body: some View {
        if enabled {
            ZStack {
                Circle()
                    .stroke(
                        Color.gray.opacity(0.5),
                        lineWidth: 3
                    )
                Circle()
                // 2
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.gray,
                        style: StrokeStyle(
                            lineWidth: 3,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut, value: progress)
            }
        }
    }
}
