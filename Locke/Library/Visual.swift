//
//  Visual.swift
//  Locke
//
//  Created by Norris Nicholson on 8/15/23.
//

import SwiftUI
import AppKit

// @see: https://stackoverflow.com/questions/5731863/mapping-a-numeric-range-onto-another
func mapDouble(_ value: Double, _ input_start: Double, _ input_end: Double, _ output_start: Double, _ output_end: Double) -> Double {
    let slope = 1.0 * (output_end - output_start) / (input_end - input_start)
    return output_start + slope * (value - input_start)
}

func formatBytes(_ bytes: Int64) -> String {
    let bcf = ByteCountFormatter()
    bcf.allowedUnits = [.useMB, .useGB, .useTB]
    bcf.countStyle = .file
    return bcf.string(fromByteCount: bytes)
}

struct RequirementText: View {
    var iconName = "xmark.square"
    var text = ""
    var isConformedTo = false
    var body: some View {
        HStack {
            Image(systemName: isConformedTo ? "checkmark.circle" : iconName)
                .foregroundColor(isConformedTo ? Color(red: 100/255, green: 163/255, blue: 89/255) : Color(red: 251/255, green: 128/255, blue: 128/255))
                .frame(minWidth: 10)
            Text(text)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.secondary)
//                .strikethrough(isConformedTo)
            Spacer()
        }
        .padding(.horizontal)
    }
}

func calculateProportion (proportion: Double) -> (lprop: Double, rprop: Double, spacing: Double) {
    
    // Initial spacing (half of total spacing
    var spacing = 0.0025
    
    // Clamp the proportion such that the first and last 1% doesnt actually show up. This prevents a bad
    // looking bar
    var adjustedProportion = proportion
    if (adjustedProportion < 0.01) {
        adjustedProportion = 0
    } else if (adjustedProportion > 0.99) {
        adjustedProportion = 1
    }
    
    // Initial l and r proportions
    var lprop = adjustedProportion
    var rprop = 1 - adjustedProportion
    
    // If we are nearing either edge, change how we calculate spacing, lprop, and rprop
    // Once lprop is less than spacing, it is no longer visible
    if (lprop < spacing) {
        // The spacing takes over for lprop
        spacing = lprop
        
        // rprop is now based on the remainder without spacing
        rprop = 1 - spacing
        
        // lprop becomes zero
        lprop = 0
    } else if (rprop < spacing) {
        // The spacing takes over for rprop
        spacing = rprop
        
        // lprop is now based on the remainder without spacing
        lprop = 1 - spacing
        
        // rprop becomes zero
        rprop = 0
    }
    return (lprop, rprop, spacing)
}

func buildText(_ width: Double, _ proportion: Double, _ size: Int64, _ quantifier: String) -> String {
    if (width > 150) {
        return "\(formatBytes(size)) \(quantifier) (\(lround(proportion * 100))%)"
    } else if (width > 120) {
        return "\(formatBytes(size)) \(quantifier)"
    } else if (width > 35) {
        return "\(lround(proportion * 100))%"
    } else {
        return " "
    }
}

struct SizeBar: View {
    @Binding var size: Int64
    @Binding var maxSize: Int16
    @State var textHidePixels: Double = 150
    
    @State private var remainingSize: Int64 = 0
    @State private var proportion: Double = 0
    
    @State private var leftProportion: Double = 0
    @State private var rightProportion: Double = 0
    @State private var spacing: Double = 0
    
    private let textPadding: CGFloat = 25
    
    var body: some View {
        GeometryReader { geometry in
            
            // Calculate the left and right widths.
            // Take their proportions normalized to the width of the frame. Then subtract spacing. Finally clamp to the size of the frame
            @State var leftWidth = (geometry.size.width * leftProportion - (geometry.size.width * spacing)).clamped(0, geometry.size.width)
            @State var rightWidth = (geometry.size.width * rightProportion - (geometry.size.width * spacing)).clamped(0, geometry.size.width)
            
            HStack(spacing: 0) {
                ZStack (alignment: .trailing) {
                    RoundedRectangle(cornerSize: .init(width: 5, height: 5)).fill(.gray)
                    HStack {
                        Spacer().frame(maxWidth: textPadding)
                        Text(buildText(leftWidth, leftProportion, size, "Used"))
                            .fixedSize()
                            .foregroundColor(.white)
                        Spacer().frame(idealWidth: textPadding, maxWidth: textPadding)
                    }.frame(minWidth: 0)
                }.frame(width: leftWidth)
                
                Spacer(minLength: geometry.size.width * spacing * 2)
                
                ZStack (alignment: .trailing) {
//                    RoundedRectangle(cornerSize: .init(width: 5, height: 5)).fill(Color(red: 71/255, green: 159/255, blue: 235/255))
                    RoundedRectangle(cornerSize: .init(width: 5, height: 5)).fill(Color("Icon"))
                    HStack {
                        Spacer().frame(maxWidth: textPadding)
                        Text(buildText(rightWidth, rightProportion, remainingSize, "Free"))
                            .fixedSize()
                            .foregroundColor(.white)
                        Spacer().frame(idealWidth: textPadding, maxWidth: textPadding)
                    }.frame(minWidth: 0)
                }.frame(width: rightWidth)
            }
        }
        .task(id: size) {
            let convertedMaxSize: Int64 = Int64(maxSize) * 1000 * 1000 * 1000
            remainingSize = convertedMaxSize - (size)
            proportion = Double(size) / Double(convertedMaxSize)
            
            let ret = calculateProportion(proportion: proportion)
            leftProportion = ret.lprop
            rightProportion = ret.rprop
            spacing = ret.spacing
        }
    }
}

struct FormField: View {
    var fieldName = ""
    @Binding var fieldValue: String
    var body: some View {
        VStack {
            TextField(fieldName, text: $fieldValue)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .regular, design: .monospaced))
                .padding(.horizontal)
            Divider()
            .frame(height: 1)
            .background(Color(red: 240/255, green: 240/255, blue: 240/255))
            .padding(.horizontal)
        }
    }
}

struct SecureFormField: View {
    var fieldName = ""
    @Binding var fieldValue: String
    @State var passwordVisible = false
    
    var body: some View {
        VStack {
            Spacer()
            HStack{
                if (passwordVisible) {
                    TextField(fieldName, text: $fieldValue)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .frame(height: 30)
                } else {
                    SecureField(fieldName, text: $fieldValue)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .frame(height: 30)
                }
                Button {
                    self.passwordVisible = !self.passwordVisible
                } label: {
                    Image(systemName: passwordVisible ? "eye.fill" : "eye.slash.fill")
                        .opacity(0.5)
                }.buttonStyle(.plain)
            }.padding(.horizontal)
            Divider()
            .frame(height: 1)
            .background(Color(red: 240/255, green: 240/255, blue: 240/255))
            .padding(.horizontal)
        }
    }
}

import SwiftUI

struct VisualEffectView: NSViewRepresentable
{
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView
    {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = NSVisualEffectView.State.active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context)
    {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}
