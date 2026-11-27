class AppConfig {
  AppConfig._();

  static const yandexMusic = 'ru.yandex.music';
  static const yandexNavigator = 'ru.yandex.yandexnavi';
  static const yandexMaps = 'ru.yandex.yandexmaps';

  static String appName(String? packageName) {
    if (packageName == null) return '';
    if (packageName == yandexMusic) return 'Яндекс Музыка';
    return packageName;
  }
}
