import Foundation

// Daemon entry point. Stays alive to serve XPC connections.
let service = DaemonService()
service.start()
RunLoop.main.run()
