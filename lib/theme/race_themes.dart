import 'package:flutter/material.dart';

/// Theme, car-style and track-style catalog for Drift Racer.
///
/// Art direction: physical toy-car racing — chunky die-cast cars on real
/// asphalt ovals, grassy park grounds, wooden fences. No neon, no cyberpunk,
/// no AI-dashboard looks. The variety comes from different grounds, track
/// surfaces, fence materials and car paint jobs.
///
/// Field mapping: woodDark/woodMid/woodDeep = paddock (UI backdrop) dark /
/// mid / deep; felt = grass/ground green; trackLight/trackDark = asphalt
/// surface; accent = trophy gold / race-metal trim.
class RaceThemeDef {
  final String id;
  final String name;
  final Color woodDark;
  final Color woodMid;
  final Color woodDeep;
  final Color accent;
  final Color accentLight;
  final Color accentDark;
  final Color ivory;
  final Color felt;
  final Color trackLight;
  final Color trackDark;
  final List<Color> playerColors;
  final List<String> playerColorNames;

  const RaceThemeDef({
    required this.id,
    required this.name,
    required this.woodDark,
    required this.woodMid,
    required this.woodDeep,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.ivory,
    required this.felt,
    required this.trackLight,
    required this.trackDark,
    required this.playerColors,
    required this.playerColorNames,
  });
}

class RaceThemes {
  /// First 4 are the FREE starter themes. The rest are PRO.
  static const List<String> freeThemeIds = [
    'park',
    'ranch',
    'alpine',
    'harbor',
  ];

  static bool isProTheme(String id) => !freeThemeIds.contains(id) && id != 'custom';

  static const List<RaceThemeDef> all = [
    RaceThemeDef(
      id: 'park',
      name: 'Park Oval',
      woodDark: Color(0xFF2E2A1F),
      woodMid: Color(0xFF4A4132),
      woodDeep: Color(0xFF1B1712),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF3E7A34),
      trackLight: Color(0xFF5A5A5C),
      trackDark: Color(0xFF3F3F41),
      playerColors: [
        Color(0xFFC23B22),
        Color(0xFF2B6CB0),
        Color(0xFF2F9E44),
        Color(0xFFD9A62B),
      ],
      playerColorNames: ['Cherry', 'Cobalt', 'Meadow', 'Taxi'],
    ),
    RaceThemeDef(
      id: 'ranch',
      name: 'Dusty Ranch',
      woodDark: Color(0xFF3A2A18),
      woodMid: Color(0xFF5A4226),
      woodDeep: Color(0xFF221709),
      accent: Color(0xFFB0792F),
      accentLight: Color(0xFFE0B36A),
      accentDark: Color(0xFF7A5520),
      ivory: Color(0xFFF7EEDC),
      felt: Color(0xFFA8843F),
      trackLight: Color(0xFF8A6A42),
      trackDark: Color(0xFF6B4F2E),
      playerColors: [
        Color(0xFF8C3B1F),
        Color(0xFF2E5E4E),
        Color(0xFFC7A23A),
        Color(0xFF4A6B8A),
      ],
      playerColorNames: ['Rust', 'Sage', 'Wheat', 'Denim'],
    ),
    RaceThemeDef(
      id: 'alpine',
      name: 'Summit Pine',
      woodDark: Color(0xFF1E2B26),
      woodMid: Color(0xFF35473E),
      woodDeep: Color(0xFF101814),
      accent: Color(0xFFB8BFC9),
      accentLight: Color(0xFFE4E9F1),
      accentDark: Color(0xFF767E8A),
      ivory: Color(0xFFF2F4EE),
      felt: Color(0xFF2F5D43),
      trackLight: Color(0xFF62666B),
      trackDark: Color(0xFF46484C),
      playerColors: [
        Color(0xFFB03A2E),
        Color(0xFF2471A3),
        Color(0xFFD4AC0D),
        Color(0xFF5D6D7E),
      ],
      playerColorNames: ['Brick', 'Glacier', 'Summit', 'Slate'],
    ),
    RaceThemeDef(
      id: 'harbor',
      name: 'Harbor Dock',
      woodDark: Color(0xFF232D33),
      woodMid: Color(0xFF3B4A54),
      woodDeep: Color(0xFF141B1F),
      accent: Color(0xFFC98F3D),
      accentLight: Color(0xFFEEC27E),
      accentDark: Color(0xFF8A5F24),
      ivory: Color(0xFFF3EEE2),
      felt: Color(0xFF4E7A6B),
      trackLight: Color(0xFF6B6F72),
      trackDark: Color(0xFF4C4F52),
      playerColors: [
        Color(0xFF1F6F8B),
        Color(0xFFC0392B),
        Color(0xFFE67E22),
        Color(0xFF7D9B76),
      ],
      playerColorNames: ['Tide', 'Buoy', 'Coral', 'Kelp'],
    ),
    RaceThemeDef(
      id: 'canyon',
      name: 'Canyon Dust',
      woodDark: Color(0xFF3A231A),
      woodMid: Color(0xFF5C3826),
      woodDeep: Color(0xFF201209),
      accent: Color(0xFFD4A24A),
      accentLight: Color(0xFFF0CD85),
      accentDark: Color(0xFF8F6A28),
      ivory: Color(0xFFF8F0DE),
      felt: Color(0xFF9A5A34),
      trackLight: Color(0xFF7A4A30),
      trackDark: Color(0xFF5C3520),
      playerColors: [
        Color(0xFFA93226),
        Color(0xFF6E2C00),
        Color(0xFFD4AC0D),
        Color(0xFF5D4037),
      ],
      playerColorNames: ['Mesa', 'Clay', 'Gila', 'Stone'],
    ),
    RaceThemeDef(
      id: 'floodlight',
      name: 'Night Grandstand',
      woodDark: Color(0xFF191B24),
      woodMid: Color(0xFF2B2E3D),
      woodDeep: Color(0xFF0C0D13),
      accent: Color(0xFFE0B34C),
      accentLight: Color(0xFFF7DE9A),
      accentDark: Color(0xFF99722A),
      ivory: Color(0xFFF5F1E6),
      felt: Color(0xFF2E4632),
      trackLight: Color(0xFF55565A),
      trackDark: Color(0xFF3A3B3E),
      playerColors: [
        Color(0xFFC0392B),
        Color(0xFF2E86C1),
        Color(0xFFF0C419),
        Color(0xFF8E44AD),
      ],
      playerColorNames: ['Comet', 'Beacon', 'Flare', 'Violet'],
    ),
    RaceThemeDef(
      id: 'autumn',
      name: 'Autumn Circuit',
      woodDark: Color(0xFF33241A),
      woodMid: Color(0xFF4E3A26),
      woodDeep: Color(0xFF1C120A),
      accent: Color(0xFFC4742C),
      accentLight: Color(0xFFE8A85E),
      accentDark: Color(0xFF814E1A),
      ivory: Color(0xFFF7EFDE),
      felt: Color(0xFF7A5A24),
      trackLight: Color(0xFF5E5650),
      trackDark: Color(0xFF443E3A),
      playerColors: [
        Color(0xFF922B21),
        Color(0xFFB45F06),
        Color(0xFF6B8E23),
        Color(0xFF4A235A),
      ],
      playerColorNames: ['Maple', 'Pumpkin', 'Moss', 'Plum'],
    ),
    RaceThemeDef(
      id: 'seaside',
      name: 'Seaside Mile',
      woodDark: Color(0xFF26333A),
      woodMid: Color(0xFF42555E),
      woodDeep: Color(0xFF141E23),
      accent: Color(0xFFD9B45B),
      accentLight: Color(0xFFF2DCA0),
      accentDark: Color(0xFF94742E),
      ivory: Color(0xFFF6F1E4),
      felt: Color(0xFFC2A86B),
      trackLight: Color(0xFF7C7A72),
      trackDark: Color(0xFF5A5850),
      playerColors: [
        Color(0xFF1A7A8C),
        Color(0xFFE76F51),
        Color(0xFFF4A261),
        Color(0xFF264653),
      ],
      playerColorNames: ['Wave', 'Shell', 'Sand', 'Deep'],
    ),
    RaceThemeDef(
      id: 'snowcap',
      name: 'Snowcap Rally',
      woodDark: Color(0xFF2A3440),
      woodMid: Color(0xFF46566A),
      woodDeep: Color(0xFF161D26),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF4F6F8),
      felt: Color(0xFFDCE5EC),
      trackLight: Color(0xFF8B95A1),
      trackDark: Color(0xFF646E7A),
      playerColors: [
        Color(0xFFC0392B),
        Color(0xFF1F618D),
        Color(0xFF117A65),
        Color(0xFF6C3483),
      ],
      playerColorNames: ['Holly', 'Frost', 'Pine', 'Berry'],
    ),
    RaceThemeDef(
      id: 'safari',
      name: 'Trail Rally',
      woodDark: Color(0xFF2F2A1A),
      woodMid: Color(0xFF4D452B),
      woodDeep: Color(0xFF1A1509),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF6F0DC),
      felt: Color(0xFF8F7A2E),
      trackLight: Color(0xFF7A6248),
      trackDark: Color(0xFF5A4630),
      playerColors: [
        Color(0xFF935116),
        Color(0xFF1E8449),
        Color(0xFFB7950B),
        Color(0xFF5D6D7E),
      ],
      playerColorNames: ['Lion', 'Acacia', 'Zebra', 'Rhino'],
    ),
    RaceThemeDef(
      id: 'orchard',
      name: 'Orchard Loop',
      woodDark: Color(0xFF27301C),
      woodMid: Color(0xFF414E2D),
      woodDeep: Color(0xFF141A0E),
      accent: Color(0xFFB03A2E),
      accentLight: Color(0xFFE08A7E),
      accentDark: Color(0xFF7A241B),
      ivory: Color(0xFFF5F2E4),
      felt: Color(0xFF4A7A2E),
      trackLight: Color(0xFF6B5B4A),
      trackDark: Color(0xFF4F4134),
      playerColors: [
        Color(0xFFA93226),
        Color(0xFF2E86C1),
        Color(0xFF7DCEA0),
        Color(0xFFD4AC0D),
      ],
      playerColorNames: ['Apple', 'Sky', 'Leaf', 'Honey'],
    ),
    RaceThemeDef(
      id: 'sunset',
      name: 'Sunset Dunes',
      woodDark: Color(0xFF33241C),
      woodMid: Color(0xFF4F3A2C),
      woodDeep: Color(0xFF1B1210),
      accent: Color(0xFFD97941),
      accentLight: Color(0xFFF2B183),
      accentDark: Color(0xFF8F4E24),
      ivory: Color(0xFFF8F0E2),
      felt: Color(0xFFB08A4E),
      trackLight: Color(0xFF6E5A52),
      trackDark: Color(0xFF51403A),
      playerColors: [
        Color(0xFFBA4A00),
        Color(0xFF7D3C98),
        Color(0xFF2E86C1),
        Color(0xFF229954),
      ],
      playerColorNames: ['Ember', 'Dusk', 'Tide', 'Palm'],
    ),
  ];

  static RaceThemeDef byId(String id, {RaceThemeDef? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }
}

/// Car body styles (die-cast toy variants). First 4 free, rest PRO.
class CarStyles {
  static const List<String> names = [
    'Speedster',
    'Coupe',
    'Buggy',
    'Pickup',
    'Stock Car',
    'Roadster',
    'Taxi Cab',
    'Muscle',
    'Micro',
    'Monster',
  ];

  /// Draw variant index: 0 wedge, 1 classic, 2 buggy (open top),
  /// 3 pickup (bed), 4 stock (spoiler), 5 roadster (low), 6 taxi (sign),
  /// 7 muscle (hood scoop), 8 micro (short), 9 monster (big wheels).
  static int variant(int i) => i.clamp(0, names.length - 1);

  static bool isPro(int i) => i >= 4;

  static const List<String> blurbs = [
    'A wedge of pure speed.',
    'The classic garage coupe.',
    'Open-top dune runner.',
    'Hauls anything, drifts everything.',
    'Spoilered oval specialist.',
    'Low, sleek and sassy.',
    'Fare included. Tips in drifts.',
    'Big hood, bigger attitude.',
    'Tiny but mighty.',
    'Crushes kerbs for breakfast.',
  ];
}

/// Track layouts. First 4 free, rest PRO.
/// [aspect]: ellipse height/width (1 = circle). [superExp]: 2 = ellipse,
/// higher = rounded-rectangle. [wobble]: S-bend modulation. [width]: track
/// width as fraction of the base radius.
class TrackStyles {
  static const List<String> names = [
    'Park Oval',
    'Tight Corners',
    'Speed Ring',
    'Winding Loop',
    'Grandstand Oval',
    'Harbor Hairpin',
    'Mountain Switchback',
    'Beach Loop',
    'Stadium Bowl',
    'Village Circuit',
  ];

  static const List<double> aspect = [
    0.78, 0.72, 1.0, 0.82, 0.62, 0.75, 0.85, 0.9, 0.55, 0.78,
  ];
  static const List<double> superExp = [
    2.0, 4.0, 2.0, 2.0, 2.0, 6.0, 2.0, 2.0, 2.0, 3.0,
  ];
  static const List<double> wobble = [
    0.0, 0.0, 0.0, 0.09, 0.0, 0.0, 0.16, 0.05, 0.0, 0.04,
  ];
  static const List<double> width = [
    0.30, 0.26, 0.34, 0.28, 0.36, 0.24, 0.24, 0.32, 0.30, 0.28,
  ];

  static bool isPro(int i) => i >= 4;

  static int clampIndex(int i) => i.clamp(0, names.length - 1);
}

/// Custom theme creator keys → color roles.
class CustomKeys {
  static const List<String> keys = [
    'ground',
    'groundMid',
    'groundDeep',
    'grass',
    'trackLight',
    'trackDark',
    'accent',
    'accentLight',
    'accentDark',
    'ivory',
    'pc0',
    'pc1',
    'pc2',
    'pc3',
  ];

  static const Map<String, String> labels = {
    'ground': 'Backdrop dark',
    'groundMid': 'Backdrop mid',
    'groundDeep': 'Backdrop deep',
    'grass': 'Ground green',
    'trackLight': 'Track light',
    'trackDark': 'Track dark',
    'accent': 'Trophy trim',
    'accentLight': 'Trim light',
    'accentDark': 'Trim dark',
    'ivory': 'Text ivory',
    'pc0': 'Paint 1',
    'pc1': 'Paint 2',
    'pc2': 'Paint 3',
    'pc3': 'Paint 4',
  };

  static const Map<String, int> defaults = {
    'ground': 0xFF2E2A1F,
    'groundMid': 0xFF4A4132,
    'groundDeep': 0xFF1B1712,
    'grass': 0xFF3E7A34,
    'trackLight': 0xFF5A5A5C,
    'trackDark': 0xFF3F3F41,
    'accent': 0xFFC9A227,
    'accentLight': 0xFFE8CE7A,
    'accentDark': 0xFF8A6D1A,
    'ivory': 0xFFF5EFE0,
    'pc0': 0xFFC23B22,
    'pc1': 0xFF2B6CB0,
    'pc2': 0xFF2F9E44,
    'pc3': 0xFFD9A62B,
  };
}
