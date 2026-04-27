// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

Future<XFile?> pickImageFromCamera({
  int imageQuality = 85,
  double? maxWidth,
}) async {
  final mediaDevices = html.window.navigator.mediaDevices;
  if (mediaDevices == null) {
    return null;
  }

  final stream = await mediaDevices.getUserMedia({
    'video': {'facingMode': 'environment'},
    'audio': false,
  });

  final overlay = html.DivElement()
    ..style.position = 'fixed'
    ..style.top = '0'
    ..style.right = '0'
    ..style.bottom = '0'
    ..style.left = '0'
    ..style.zIndex = '2147483647'
    ..style.backgroundColor = 'rgba(0, 0, 0, 0.88)'
    ..style.display = 'flex'
    ..style.alignItems = 'center'
    ..style.justifyContent = 'center'
    ..style.padding = '16px';

  final panel = html.DivElement()
    ..style.width = 'min(92vw, 720px)'
    ..style.backgroundColor = '#111827'
    ..style.borderRadius = '20px'
    ..style.overflow = 'hidden'
    ..style.boxShadow = '0 24px 80px rgba(0,0,0,0.45)';

  final header = html.DivElement()
    ..text = 'Take a photo'
    ..style.padding = '14px 18px'
    ..style.color = 'white'
    ..style.fontFamily = 'sans-serif'
    ..style.fontSize = '18px'
    ..style.fontWeight = '600'
    ..style.backgroundColor = '#1F2937';

  final videoWrap = html.DivElement()
    ..style.position = 'relative'
    ..style.backgroundColor = 'black';

  final video = html.VideoElement()
    ..autoplay = true
    ..muted = true
    ..srcObject = stream
    ..style.width = '100%'
    ..style.maxHeight = '70vh'
    ..style.objectFit = 'cover';
  video.setAttribute('playsinline', 'true');

  videoWrap.children = [video];

  final footer = html.DivElement()
    ..style.display = 'flex'
    ..style.gap = '12px'
    ..style.justifyContent = 'space-between'
    ..style.padding = '16px'
    ..style.backgroundColor = '#111827';

  final cancelButton = html.ButtonElement()
    ..text = 'Cancel'
    ..style.flex = '1'
    ..style.padding = '12px 16px'
    ..style.border = 'none'
    ..style.borderRadius = '12px'
    ..style.backgroundColor = '#374151'
    ..style.color = 'white'
    ..style.fontSize = '16px'
    ..style.cursor = 'pointer';

  final captureButton = html.ButtonElement()
    ..text = 'Capture'
    ..style.flex = '1'
    ..style.padding = '12px 16px'
    ..style.border = 'none'
    ..style.borderRadius = '12px'
    ..style.backgroundColor = '#2E7D32'
    ..style.color = 'white'
    ..style.fontSize = '16px'
    ..style.cursor = 'pointer';

  footer.children = [cancelButton, captureButton];
  panel.children = [header, videoWrap, footer];
  overlay.children = [panel];
  html.document.body?.append(overlay);

  final completer = Completer<XFile?>();

  Future<void> cleanup() async {
    stream.getTracks().forEach((track) => track.stop());
    overlay.remove();
  }

  cancelButton.onClick.listen((_) async {
    await cleanup();
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  });

  captureButton.onClick.listen((_) async {
    final canvas = html.CanvasElement();
    final width = video.videoWidth;
    final height = video.videoHeight;
    if (width == 0 || height == 0) {
      return;
    }

    canvas.width = width;
    canvas.height = height;
    final ctx = canvas.context2D;
    ctx.drawImageScaled(video, 0, 0, width, height);

    final dataUrl = canvas.toDataUrl('image/jpeg', imageQuality / 100);
    final base64Data = dataUrl.split(',').last;
    final bytes = base64Decode(base64Data);

    await cleanup();
    if (!completer.isCompleted) {
      completer.complete(XFile.fromData(
        Uint8List.fromList(bytes),
        name: 'camera.jpg',
        mimeType: 'image/jpeg',
      ));
    }
  });

  video.onLoadedMetadata.first.then((_) => video.play());

  return completer.future;
}

Future<XFile?> pickImageFromGallery({
  int imageQuality = 85,
  double? maxWidth,
}) async {
  final input = html.FileUploadInputElement()..accept = 'image/*';
  input.click();

  await input.onChange.first;
  if (input.files == null || input.files!.isEmpty) {
    return null;
  }

  final file = input.files!.first;
  final reader = html.FileReader();
  final completer = Completer<XFile?>();

  reader.onLoadEnd.listen((_) {
    final buffer = reader.result;
    if (buffer is! ByteBuffer) {
      completer.complete(null);
      return;
    }
    final bytes = Uint8List.view(buffer);
    completer.complete(XFile.fromData(
      bytes,
      name: file.name,
      mimeType: file.type,
    ));
  });

  reader.onError.listen((_) => completer.complete(null));
  reader.readAsArrayBuffer(file);
  return completer.future;
}