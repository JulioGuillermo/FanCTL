import Foundation

// Punto de entrada del daemon. Se mantiene vivo para servir conexiones XPC.
let service = DaemonService()
service.start()
RunLoop.main.run()
