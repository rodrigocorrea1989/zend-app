import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'rider_service.dart' show RegistroException;

/// Foto de perfil: sube la imagen a Supabase Storage (bucket `avatars`) y
/// guarda la ruta en `profiles.avatar_path` (ver supabase/profile_avatars.sql).
class AvatarService {
  AvatarService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _bucket = 'avatars';
  static const _maxBytes = 2 * 1024 * 1024;

  /// URL pública de una ruta guardada en `profiles.avatar_path`.
  static String urlFor(String path) =>
      Supabase.instance.client.storage.from(_bucket).getPublicUrl(path);

  /// Ruta de la foto del usuario actual, o `null` si no tiene o no se pudo leer.
  Future<String?> currentPath() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await _client
          .from('profiles')
          .select('avatar_path')
          .eq('id', uid)
          .maybeSingle();
      final p = row?['avatar_path'] as String?;
      return (p == null || p.isEmpty) ? null : p;
    } catch (e) {
      debugPrint('leer avatar falló: $e');
      return null;
    }
  }

  /// Sube la foto, la guarda en el perfil y borra la anterior.
  /// Devuelve la ruta nueva. Lanza [RegistroException] si falla.
  Future<String> upload(Uint8List bytes) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw RegistroException('Tu sesión expiró. Volvé a ingresar.');
    }
    if (bytes.lengthInBytes > _maxBytes) {
      throw RegistroException('La foto es demasiado pesada (máximo 2 MB).');
    }

    final old = await currentPath();
    // Nombre nuevo en cada subida: así nunca se ve una foto vieja en caché.
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      await _client.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '31536000',
            ),
          );
      await _client.rpc('set_avatar', params: {'p_path': path});
    } on StorageException catch (e) {
      debugPrint('subir foto falló: ${e.statusCode} ${e.message}');
      throw RegistroException('No pudimos subir la foto. Intentá de nuevo.');
    } on PostgrestException catch (e) {
      debugPrint('set_avatar falló: ${e.code} ${e.message}');
      if (e.code == 'PGRST202') {
        throw RegistroException(
            'Falta crear la función set_avatar en Supabase '
            '(ejecutá supabase/profile_avatars.sql).');
      }
      throw RegistroException('No pudimos guardar la foto. Intentá de nuevo.');
    } catch (_) {
      throw RegistroException('No pudimos conectarnos. Revisá tu internet.');
    }

    if (old != null && old != path) {
      try {
        await _client.storage.from(_bucket).remove([old]);
      } catch (_) {}
    }
    return path;
  }

  /// Igual que [upload] pero sin lanzar errores (para el registro).
  Future<void> uploadSilently(Uint8List bytes) async {
    try {
      await upload(bytes);
    } catch (e) {
      debugPrint('subida silenciosa falló: $e');
    }
  }

  // ---------- Foto elegida en el registro, pendiente de subir ----------
  //
  // Si el registro exige confirmar el email todavía no hay sesión y Storage
  // no deja subir. La guardamos en el dispositivo (una por email) y se sube
  // en el primer ingreso.

  Future<File?> _pendingFile(String email) async {
    if (kIsWeb) return null;
    final dir = await getApplicationSupportDirectory();
    final key = base64Url
        .encode(utf8.encode(email.trim().toLowerCase()))
        .replaceAll('=', '');
    return File('${dir.path}/pending_avatar_$key.jpg');
  }

  Future<void> savePending(String email, Uint8List bytes) async {
    try {
      final f = await _pendingFile(email);
      if (f == null) return;
      await f.writeAsBytes(bytes, flush: true);
    } catch (e) {
      debugPrint('guardar foto pendiente falló: $e');
    }
  }

  /// Sube la foto pendiente del usuario actual, si hay. Devuelve la ruta
  /// nueva o `null`. Nunca lanza errores.
  Future<String?> uploadPendingIfAny() async {
    try {
      final email = _client.auth.currentUser?.email;
      if (email == null) return null;
      final f = await _pendingFile(email);
      if (f == null || !await f.exists()) return null;
      final path = await upload(await f.readAsBytes());
      await f.delete();
      return path;
    } catch (e) {
      debugPrint('subir foto pendiente falló: $e');
      return null;
    }
  }
}
