import SwiftUI

// MARK: - Create Container Sheet

struct CreateContainerView: View {
    @Bindable var viewModel: ContainerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showAdvanced = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Container")
                    .font(.title2).bold()
                Spacer()
                if !viewModel.isCreating && viewModel.createForm.createdContainerId == nil {
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.escape)
                }
            }
            .padding()

            Divider()

            if let containerId = viewModel.createForm.createdContainerId {
                successView(containerId)
            } else {
                formScrollView
            }
        }
        .frame(width: 580, height: 560)
        .frame(minHeight: 420)
    }

    // MARK: - Success

    private func successView(_ containerId: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("Container Created")
                .font(.title3).bold()

            Text(containerId)
                .font(.body.monospaced())
                .foregroundColor(.secondary)
                .textSelection(.enabled)
                .padding(.horizontal)
                .lineLimit(1)

            ProgressView()
                .scaleEffect(0.8)
            Text("Closing...")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Form

    private var formScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                basicSection
                portMappingsSection
                volumeMountsSection
                resourcesSection
                envVarsSection
                advancedSection
                errorSection
                actionButtons
            }
            .padding()
        }
    }

    // MARK: - Basic Info

    private var basicSection: some View {
        GroupBox("Image & Name") {
            VStack(alignment: .leading, spacing: 8) {
                // Image — picker + manual input
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Image *")
                            .font(.headline)
                        Spacer()
                        if !viewModel.availableImages.isEmpty {
                            Picker("", selection: $viewModel.createForm.image) {
                                Text("").tag("")
                                ForEach(viewModel.availableImages, id: \.id) { img in
                                    Text(img.reference).tag(img.reference)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                    }
                    TextField("e.g. nginx:latest", text: $viewModel.createForm.image)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                }

                // Name
                labeledField("Name") {
                    TextField("Optional container name", text: $viewModel.createForm.name)
                        .textFieldStyle(.roundedBorder)
                }

                // Command
                labeledField("Command") {
                    TextField("e.g. --port 8080:80 nginx -g 'daemon off;'", text: $viewModel.createForm.command)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                }

                // Network
                VStack(alignment: .leading, spacing: 4) {
                    Text("Network").font(.caption).foregroundColor(.secondary)
                    if viewModel.availableNetworks.isEmpty {
                        TextField("bridge (default)", text: $viewModel.createForm.network)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Picker("", selection: $viewModel.createForm.network) {
                            Text("Default (bridge)").tag("")
                            ForEach(viewModel.availableNetworks, id: \.id) { net in
                                Text(net.name).tag(net.name)
                            }
                            Text("Custom...").tag("__custom__")
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()

                        if viewModel.createForm.network == "__custom__" {
                            TextField("Enter network name", text: $viewModel.createForm.network)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                // Machine
                if !viewModel.availableMachines.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Machine").font(.caption).foregroundColor(.secondary)
                        Picker("", selection: $viewModel.createForm.selectedMachine) {
                            Text("Default").tag("")
                            ForEach(viewModel.availableMachines, id: \.name) { m in
                                HStack(spacing: 8) {
                                    Circle().fill(m.status == .running ? Color.green : Color.red).frame(width: 6, height: 6)
                                    Text(m.name)
                                }.tag(m.name)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }
            }
            .padding(8)
        }
    }

    // MARK: - Port Mappings

    private var portMappingsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Port Mappings", systemImage: "arrow.triangle.swap")
                ForEach(viewModel.createForm.portMappings.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 6) {
                        // Mode toggle
                        Picker("", selection: $viewModel.createForm.portMappings[index].useRawSpec) {
                            Text("Simple (host:container)").tag(false)
                            Text("Custom format").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        if viewModel.createForm.portMappings[index].useRawSpec {
                            // Raw port spec
                            HStack(spacing: 8) {
                                TextField("e.g. 127.0.0.1:8080:80/udp", text: $viewModel.createForm.portMappings[index].rawSpec)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.caption.monospaced())
                                    .help("Format: [host-ip:]host-port:container-port[/protocol]")

                                removeButton {
                                    viewModel.createForm.portMappings.remove(at: index)
                                }
                            }
                        } else {
                            // Structured host:container:protocol
                            HStack(spacing: 8) {
                                TextField("Host", value: $viewModel.createForm.portMappings[index].hostPort, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 70)
                                    .help("Host port")

                                Text(":").foregroundColor(.secondary)

                                TextField("Container", value: $viewModel.createForm.portMappings[index].containerPort, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 70)
                                    .help("Container port")

                                Picker("", selection: $viewModel.createForm.portMappings[index].protocolType) {
                                    Text("tcp").tag("tcp")
                                    Text("udp").tag("udp")
                                }
                                .pickerStyle(.menu)
                                .frame(width: 60)
                                .labelsHidden()

                                removeButton {
                                    viewModel.createForm.portMappings.remove(at: index)
                                }
                            }
                        }
                    }
                }
                addButton("Add Port Mapping") {
                    viewModel.createForm.portMappings.append(PortMappingEntry())
                }
            }
            .padding(8)
        }
    }

    // MARK: - Volume Mounts

    private var volumeMountsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Volume Mounts", systemImage: "externaldrive")
                ForEach(viewModel.createForm.volumeMounts.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 6) {
                        // Mode picker: bind mount or existing volume
                        Picker("", selection: $viewModel.createForm.volumeMounts[index].useExistingVolume) {
                            Text("Bind Mount (host path)").tag(false)
                            if !viewModel.availableVolumes.isEmpty {
                                Text("Existing Volume").tag(true)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        HStack(spacing: 8) {
                            if viewModel.createForm.volumeMounts[index].useExistingVolume {
                                // Pick from existing volumes
                                Picker("", selection: $viewModel.createForm.volumeMounts[index].source) {
                                    Text("Select a volume...").tag("")
                                    ForEach(viewModel.availableVolumes, id: \.name) { vol in
                                        Text(vol.name).tag(vol.name)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(minWidth: 160)
                            } else {
                                // Manual host path
                                TextField("Host path", text: $viewModel.createForm.volumeMounts[index].source)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.caption.monospaced())
                                    .help("Host source path")
                            }

                            Text(":").foregroundColor(.secondary)

                            TextField("Container path", text: $viewModel.createForm.volumeMounts[index].target)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption.monospaced())
                                .help("Container target path")

                            removeButton {
                                viewModel.createForm.volumeMounts.remove(at: index)
                            }
                        }
                    }
                }
                addButton("Add Volume Mount") {
                    viewModel.createForm.volumeMounts.append(VolumeMountEntry())
                }
            }
            .padding(8)
        }
    }

    // MARK: - Resources

    private var resourcesSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Resources", systemImage: "cpu")
                HStack(spacing: 16) {
                    labeledField("CPUs") {
                        TextField("Unlimited", value: $viewModel.createForm.cpus, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                    labeledField("Memory") {
                        TextField("e.g. 512M, 2G", text: $viewModel.createForm.memory)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                    }
                    Spacer()
                }
            }
            .padding(8)
        }
    }

    // MARK: - Environment Variables

    private var envVarsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Environment Variables", systemImage: "gearshape.2")
                ForEach(viewModel.createForm.envVars.indices, id: \.self) { index in
                    HStack(spacing: 8) {
                        TextField("KEY", text: $viewModel.createForm.envVars[index].key)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption.monospaced())
                            .frame(width: 140)

                        Text("=").foregroundColor(.secondary)

                        TextField("value", text: $viewModel.createForm.envVars[index].value)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption.monospaced())

                        removeButton {
                            viewModel.createForm.envVars.remove(at: index)
                        }
                    }
                }
                addButton("Add Environment Variable") {
                    viewModel.createForm.envVars.append(KeyValueEntry())
                }
            }
            .padding(8)
        }
    }

    // MARK: - Advanced

    private var advancedSection: some View {
        DisclosureGroup(isExpanded: $showAdvanced) {
            VStack(alignment: .leading, spacing: 16) {
                Divider()

                // Workdir & Entrypoint
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Workdir & Entrypoint", systemImage: "arrow.forward")
                        labeledField("Workdir") {
                            TextField("e.g. /app", text: $viewModel.createForm.workdir)
                                .textFieldStyle(.roundedBorder)
                        }
                        labeledField("Entrypoint") {
                            TextField("Override ENTRYPOINT", text: $viewModel.createForm.entrypoint)
                                .textFieldStyle(.roundedBorder)
                        }
                        labeledField("User") {
                            TextField("e.g. 1000:1000", text: $viewModel.createForm.user)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(8)
                }

                // Platform
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Platform", systemImage: "circle.hexagongrid")
                        labeledField("Platform") {
                            TextField("e.g. linux/arm64", text: $viewModel.createForm.platform)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Arch").font(.caption).foregroundColor(.secondary)
                                Picker("", selection: $viewModel.createForm.arch) {
                                    Text("Default").tag("")
                                    Text("arm64").tag("arm64")
                                    Text("x86_64").tag("x86_64")
                                    Text("aarch64").tag("aarch64")
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("OS").font(.caption).foregroundColor(.secondary)
                                Picker("", selection: $viewModel.createForm.os) {
                                    Text("Default").tag("")
                                    Text("linux").tag("linux")
                                    Text("darwin").tag("darwin")
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                            }
                        }
                    }
                    .padding(8)
                }

                // Labels
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Labels", systemImage: "tag")
                        ForEach(viewModel.createForm.labels.indices, id: \.self) { index in
                            HStack(spacing: 8) {
                                TextField("KEY", text: $viewModel.createForm.labels[index].key)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.caption.monospaced())
                                    .frame(width: 140)

                                Text("=").foregroundColor(.secondary)

                                TextField("value", text: $viewModel.createForm.labels[index].value)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.caption.monospaced())

                                removeButton {
                                    viewModel.createForm.labels.remove(at: index)
                                }
                            }
                        }
                        addButton("Add Label") {
                            viewModel.createForm.labels.append(KeyValueEntry())
                        }
                    }
                    .padding(8)
                }

                // DNS
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "DNS", systemImage: "network")
                        ForEach($viewModel.createForm.dnsServers.indices, id: \.self) { index in
                            HStack(spacing: 8) {
                                TextField("e.g. 8.8.8.8", text: $viewModel.createForm.dnsServers[index])
                                    .textFieldStyle(.roundedBorder)
                                    .font(.caption.monospaced())

                                removeButton {
                                    viewModel.createForm.dnsServers.remove(at: index)
                                }
                            }
                        }
                        addButton("Add DNS Server") {
                            viewModel.createForm.dnsServers.append("")
                        }
                    }
                    .padding(8)
                }

                // Advanced Flags
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Runtime Options", systemImage: "wrench.and.screwdriver")
                        Toggle("Auto-remove after stop (--rm)", isOn: $viewModel.createForm.autoRemove)
                        Toggle("Interactive (--interactive)", isOn: $viewModel.createForm.interactive)
                        Toggle("Allocate TTY (--tty)", isOn: $viewModel.createForm.tty)
                        Toggle("Read-only root filesystem (--read-only)", isOn: $viewModel.createForm.readOnly)

                        labeledField("Shared Memory Size") {
                            TextField("e.g. 64M", text: $viewModel.createForm.shmSize)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                        }
                    }
                    .padding(8)
                }
            }
            .padding(.leading, 4)
        } label: {
            HStack {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.accentColor)
                Text("Advanced Options")
                    .font(.subheadline)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Error

    @ViewBuilder
    private var errorSection: some View {
        if let error = viewModel.createErrorMessage {
            Text(error)
                .foregroundColor(.red)
                .font(.callout)
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack {
            Button(role: .cancel) {
                dismiss()
            } label: {
                Text("Cancel")
            }
            .disabled(viewModel.isCreating)
            .buttonStyle(.bordered)

            Spacer()

            Button {
                Task { await viewModel.createContainer() }
            } label: {
                if viewModel.isCreating {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16)
                    Text("Creating...")
                } else {
                    Image(systemName: "play")
                    Text("Create")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                viewModel.isCreating ||
                viewModel.createForm.image.trimmingCharacters(in: .whitespaces).isEmpty
            )
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            content()
        }
    }

    private func removeButton(action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "minus.circle.fill")
                .foregroundColor(.red)
        }
        .buttonStyle(.plain)
        .help("Remove")
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "plus")
                .font(.caption)
        }
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundColor(.accentColor)
                .font(.caption)
            Text(title)
                .font(.subheadline).bold()
                .foregroundColor(.secondary)
        }
    }
}
