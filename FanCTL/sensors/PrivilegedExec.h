#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Ejecuta comandos como root pidiendo la contraseña de administrador mediante
/// Authorization Services (API C `AuthorizationExecuteWithPrivileges`).
///
/// En Swift esa API no está disponible, por eso se envuelve aquí en Objective-C.
@interface PrivilegedExec : NSObject

/// Ejecuta `script` (código `/bin/sh`) como root.
///
/// @return Salida combinada (stdout+stderr) si el script terminó con éxito
/// (imprime la marca `FANCTL_OK`); `nil` si falló o el usuario canceló la
/// autenticación. En ese caso, consulta `lastError` para el motivo.
+ (nullable NSString *)runPrivilegedShellScript:(NSString *)script;

/// Mensaje de la última operación fallida, o `nil` si la última fue correcta.
@property (class, readonly, nullable) NSString *lastError;

@end

NS_ASSUME_NONNULL_END
