# Сторонние ассеты

Получены 12 ноября 2026 с официального сервера Poly Haven. Используются только
файлы ассетов под CC0, не изображения-превью и не оформление сайта.

| Ассет | Автор | Использование | Источник |
| --- | --- | --- | --- |
| Asphalt 02 | Rob Tuytel / Poly Haven | Diffuse, OpenGL Normal, Roughness, JPG 1K; материал дороги | https://polyhaven.com/a/asphalt_02 |
| Cobblestone Street Night | Greg Zaal / Poly Haven | HDR 1K; статическое окружение отражений | https://polyhaven.com/a/cobblestone_street_night |

Лицензия обоих ассетов: **CC0 1.0 Universal**.
[Условия Poly Haven](https://polyhaven.com/license) ·
[CC0](https://creativecommons.org/publicdomain/zero/1.0/).

Исходные файлы не редактировались. Цвет, масштаб, влажность и сила отражений
настраиваются шейдерами проекта. Панорама используется в кубической карте
отражений; в фоне остаётся собственное градиентное небо.

`third_party_manifest.json` содержит URL, размеры и SHA-256 скачанных файлов.
Модель T-Roc со Sketchfab **не скачана и не включена**: её исследование описано
отдельно в docs/asset_research_2026-11-12.md.

## Локальная модель Golf — 13 ноября 2026

Volkswagen Golf GTI (2025), **geyges**, получена пользователем через
[Sketchfab](https://sketchfab.com/3d-models/volkswagen-golf-gti-2025-84fe6c2b9feb4c8a854d16f3daf33eab).
**SKETCHFAB Standard / Free Standard**; исходная лицензия, происхождение,
контрольная сумма и изменения — в assets/cars/golf_gti_2025/.
Архив и производные модели локальные, исключены из Git. Используются внутри
игры. Закрыты двери/люк/багажник, убраны airbags и анимации, отделены колёса
и тормоза, адаптированы UV материалов, добавлена реакция стоп-сигналов.

## Audi R8 игрока — 13 ноября 2026

This work is based on "Audi R8" (https://sketchfab.com/3d-models/audi-r8-e17e438f076f4427a58d93aa779edaed)
by wallon (https://sketchfab.com/realwallon) licensed under CC-BY-4.0
(https://creativecommons.org/licenses/by/4.0/).

Получена в ZIP от пользователя. Адаптация для игры: запечены преобразования,
нормализован масштаб/направление, парные колёса разделены, убраны исходные поворот и развал,
отделены суппорты, геометрия объединена по материалам, настроены стоп-сигналы
и шероховатость. Исходные текстуры/медная краска сохранены. Подробности,
оригинальная лицензия и SHA-256 — assets/cars/audi_r8/.
