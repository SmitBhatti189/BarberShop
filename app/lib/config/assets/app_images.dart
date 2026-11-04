/// Image and logo asset paths. Add files under `assets/images/` and reference
/// them only through these constants.
abstract final class AppImages {
  static const String _base = 'assets/images';

  /// Salon logo (SVG-free PNG to avoid an extra rendering dependency).
  /// Not yet supplied — the UI falls back to [AppIcons.services] until it is.
  static const String? logo = null;

  static String path(String fileName) => '$_base/$fileName';
}
