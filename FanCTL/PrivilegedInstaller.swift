import Foundation

/// Instala y desinstala el daemon de FanCTL en `/Library/PrivilegedHelperTools`
/// y `/Library/LaunchDaemons` ejecutando un script como root mediante
/// Authorization Services (pedirá la contraseña de administrador).
///
/// A diferencia de `SMAppService.register`, este mecanismo no exige que la app
/// esté firmada con un certificado válido, por lo que funciona también con
/// firmas ad-hoc (p. ej. "Sign to Run Locally").
enum PrivilegedInstaller {
    static let daemonName = "com.jg.FanCTL.daemon"
    static let installPath = "/Library/PrivilegedHelperTools/com.jg.FanCTL.daemon"
    static let legacyPlistURL = URL(fileURLWithPath: "/Library/LaunchDaemons/com.jg.FanCTL.daemon.plist")

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: installPath)
    }

    /// Instala el binario del daemon (desde `Contents/Helpers/FanDaemon`),
    /// escribe el plist de launchd y arranca el servicio como root.
    static func install(completion: @escaping (_ ok: Bool, _ message: String?) -> Void) {
        let candidates = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/FanDaemon"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/FanDaemon")
        ]
        guard let source = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
            completion(false, "No se encontró el binario del daemon dentro de la app.")
            return
        }

        let escapedSource = source.path.replacingOccurrences(of: "'", with: "'\\''")
        let script = """
        set -e
        SRC='\(escapedSource)'
        DST=/Library/PrivilegedHelperTools/com.jg.FanCTL.daemon
        PLIST=/Library/LaunchDaemons/com.jg.FanCTL.daemon.plist
        LOGDIR=/Library/Logs/FanCTL

        mkdir -p "$LOGDIR"
        cp -f "$SRC" "$DST"
        chmod 755 "$DST"
        chown root:wheel "$DST"

        cat > "$PLIST" <<'PLISTEOF'
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        \t<key>Label</key>
        \t<string>com.jg.FanCTL.daemon</string>
        \t<key>ProgramArguments</key>
        \t<array>
        \t\t<string>/Library/PrivilegedHelperTools/com.jg.FanCTL.daemon</string>
        \t</array>
        \t<key>MachServices</key>
        \t<dict>
        \t\t<key>com.jg.FanCTL.daemon</key>
        \t\t<true/>
        \t</dict>
        \t<key>ProcessType</key>
        \t<string>Background</string>
        \t<key>RunAtLoad</key>
        \t<true/>
        \t<key>StandardOutPath</key>
        \t<string>/Library/Logs/FanCTL/fanctl-daemon.log</string>
        \t<key>StandardErrorPath</key>
        \t<string>/Library/Logs/FanCTL/fanctl-daemon.log</string>
        </dict>
        </plist>
        PLISTEOF

        chmod 644 "$PLIST"
        chown root:wheel "$PLIST"

        launchctl bootout system/com.jg.FanCTL.daemon 2>/dev/null || true
        launchctl bootstrap system "$PLIST"
        launchctl kickstart -k system/com.jg.FanCTL.daemon

        echo "FANCTL_OK"
        """

        runAsRoot(script: script, completion: completion)
    }

    /// Detiene el daemon y elimina el plist y el binario instalados.
    static func uninstall(completion: @escaping (_ ok: Bool, _ message: String?) -> Void) {
        let script = """
        launchctl bootout system/com.jg.FanCTL.daemon 2>/dev/null || true
        rm -f /Library/LaunchDaemons/com.jg.FanCTL.daemon.plist
        rm -f /Library/PrivilegedHelperTools/com.jg.FanCTL.daemon
        echo "FANCTL_OK"
        """

        runAsRoot(script: script, completion: completion)
    }

    private static func runAsRoot(script: String,
                                  completion: @escaping (_ ok: Bool, _ message: String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let escaped = script
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let appleScript = "do shell script \"\(escaped)\" with administrator privileges"

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", appleScript]
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            do {
                try process.run()
            } catch {
                DispatchQueue.main.async {
                    completion(false, "No se pudo ejecutar la instalación: \(error.localizedDescription)")
                }
                return
            }
            process.waitUntilExit()

            let output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let errorText = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                .trimmingCharacters(in: .whitespacesAndNewlines)

            DispatchQueue.main.async {
                if process.terminationStatus == 0 {
                    completion(true, output)
                } else {
                    let message = errorText.isEmpty
                        ? "La instalación no se completó (código \(process.terminationStatus))."
                        : errorText
                    completion(false, message)
                }
            }
        }
    }
}
