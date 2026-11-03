import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

/// Biggest picture kept inside the saved figures (after shrinking).
const kMaxPictureBytes = 150 * 1024;

/// Lets the admin choose a picture from their device, shrinks it and returns it
/// as a `data:` link that is saved with the figures. Null if cancelled; throws
/// a [String] message when the picture cannot be used.
Future<String?> pickPicture({double maxWidth = 480}) async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: maxWidth,
    imageQuality: 70,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.length > kMaxPictureBytes) {
    throw 'That picture is too large (${bytes.length ~/ 1024} KB). '
        'Choose a smaller one or save it as JPEG first.';
  }
  final mime = file.mimeType ?? 'image/jpeg';
  return 'data:$mime;base64,${base64Encode(bytes)}';
}

final _decoded = <String, ImageProvider>{};

/// The picture for [url]: an uploaded `data:` link or a normal web address.
ImageProvider pictureProvider(String url) {
  final u = url.trim();
  return _decoded.putIfAbsent(u, () {
    if (u.startsWith('data:')) {
      return MemoryImage(UriData.parse(u).contentAsBytes());
    }
    return NetworkImage(u);
  });
}
