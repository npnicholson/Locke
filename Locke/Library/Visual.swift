//
//  Visual.swift
//  Locke
//
//  Created by Norris Nicholson on 8/15/23.
//

import SwiftUI
import AppKit

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
            .padding(.horizontal)
        }
    }
}
