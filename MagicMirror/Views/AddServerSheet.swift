import SwiftUI

struct AddServerSheet: View {
    @Namespace var mainNamespace
    @Environment(\.dismiss) var dismiss

    var updateSelectionOnSubmit: Binding<ServerAddr?>

    @State private var host: String = ""
    @State private var port: Int = 9599

    //    @State private var insecureSkipVerify: Bool = false
    //    @State private var disableInsecureSkipVerify: Bool = true

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack {
            Form {
                addrSection
            }
            .formStyle(.grouped)
            .padding(.bottom, 10)

            HStack {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: submit) {
                    Text("Add Server")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .onAppear {
            self.host = ""
            self.port = 9599
        }
    }

    @ViewBuilder
    var addrSection: some View {
        Section {
            TextField("Hostname/IP", text: $host, prompt: Text("1.2.3.4"))
                .prefersDefaultFocus(in: mainNamespace)
            TextField("Port", value: $port, format: .number.grouping(.never))
        } header: {
            Label("Server Address", systemImage: "network")
        }

        //        Section {
        //            Toggle(isOn: $insecureSkipVerify){ Text("Skip TLS Verification") }
        //                .disabled(disableInsecureSkipVerify)
        //        } header: {
        //            Label("Connection Options", systemImage: "lock.fill")
        //        }
    }

    func submit() {
        dismiss()

        let config = ServerConfig(addr: "\(host):\(port)")
        modelContext.insert(config)
        updateSelectionOnSubmit.wrappedValue = config.serverAddress
    }
}

#Preview {
    @Previewable @State var selection: ServerAddr? = nil
    AddServerSheet(updateSelectionOnSubmit: $selection)
        .scenePadding()
        .frame(width: 400)
}
