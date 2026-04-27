import 'package:image_picker/image_picker.dart';

Future<XFile?> pickImageFromCamera({
  int imageQuality = 85,
  double? maxWidth,
}) async {
  final picker = ImagePicker();
  return picker.pickImage(
    source: ImageSource.camera,
    imageQuality: imageQuality,
    maxWidth: maxWidth,
  );
}

Future<XFile?> pickImageFromGallery({
  int imageQuality = 85,
  double? maxWidth,
}) async {
  final picker = ImagePicker();
  return picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: imageQuality,
    maxWidth: maxWidth,
  );
}