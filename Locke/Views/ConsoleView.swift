//
//  ConsoleView.swift
//  Locke
//
//  Created by Norris Nicholson on 10/16/23.
//

import SwiftUI

struct ConsoleView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack (spacing: 0.0) {
            Text("Console Output")
                .font(.system(.title3, design: .rounded))
                .bold()
                .foregroundColor(.primary)
                .padding(.vertical)
            ScrollView {
                ForEach(logger.console, id: \.date) { entry in
                    HStack (alignment: .top) {
                        Text(entry.date.description)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .fontWeight(.regular)
                            .foregroundColor(.primary)
                        HStack{
                            Text(String(describing: entry.level))
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .fontWeight(.regular)
                                .foregroundColor(entry.level == .trace ? .primary : entry.level == .error ? .red : .yellow)
                            Spacer()
                        }.frame(minWidth: 55, maxWidth: 55)
                        Text(entry.text)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .fontWeight(.regular)
                            .foregroundColor(.primary)
                        if let predicate = entry.predicate {
                            Text(String(describing: predicate))
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .fontWeight(.regular)
                                .foregroundColor(.primary)
                        }
                        Spacer()
                    }.contextMenu {
                        Button("Copy Row") {
                            logger.copy(entry)
                        }
                    }
                }
            }.padding([.leading, .bottom])
            HStack {
                Spacer()
                Button("Export") {
                    logger.export()
                }
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }.padding([.trailing, .bottom])
            
        }.frame(minWidth: 400, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
    }
}

