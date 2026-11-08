import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../servicios/avatar_service.dart';

/// Círculo con la foto (bytes en memoria o ruta de Storage) o, si no hay,
/// las iniciales del nombre.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    required this.color,
    this.path,
    this.bytes,
    this.radius = 24,
  });

  final String name;
  final Color color;
  final String? path;
  final Uint8List? bytes;
  final double radius;

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  Widget _fallback() => Center(
        child: _initials.isEmpty
            ? Icon(Icons.person, size: radius, color: color)
            : Text(
                _initials,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: radius * 0.8,
                ),
              ),
      );

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final Widget child;

    if (bytes != null) {
      child = Image.memory(bytes!, width: size, height: size, fit: BoxFit.cover);
    } else if (path != null && path!.isNotEmpty) {
      child = Image.network(
        AvatarService.urlFor(path!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } else {
      child = _fallback();
    }

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
      ),
      child: child,
    );
  }
}

/// Avatar tocable: abre cámara o galería y entrega los bytes de la foto.
/// Quien lo usa decide qué hacer con ellos (subirla ya, o guardarla).
class ProfilePhotoPicker extends StatelessWidget {
  const ProfilePhotoPicker({
    super.key,
    required this.name,
    required this.color,
    required this.onPicked,
    this.path,
    this.bytes,
    this.radius = 40,
    this.busy = false,
  });

  final String name;
  final Color color;
  final ValueChanged<Uint8List> onPicked;
  final String? path;
  final Uint8List? bytes;
  final double radius;
  final bool busy;

  Future<void> _choose(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Sacar una foto'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      // Se reduce y comprime al elegirla: pesa poco y sube rápido.
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (file == null) return;
      onPicked(await file.readAsBytes());
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No pudimos abrir la cámara o la galería.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;

    return Semantics(
      button: true,
      label: 'Cambiar foto de perfil',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : () => _choose(context),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              UserAvatar(
                name: name,
                color: color,
                path: path,
                bytes: bytes,
                radius: radius,
              ),
              if (busy)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black38,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.photo_camera,
                      size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
