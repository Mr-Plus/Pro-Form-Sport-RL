import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/models.dart';

/// Résultat décodé d'une trame télémétrique BLE de 20 octets provenant du Pro-Form Sport RL
class DecodedProFormPacket {
  final bool isStrokeVelocityFrame; // Trame A: 0xff 0x11 ...
  final bool isPowerDistanceFrame; // Trame B: 0x00 0x12 0x01 0x04 0x02 ...
  final bool isConsoleStrokesFrame; // Trame C: 0x01 0x12 0x00 0x00 0x00 ...
  final bool isConsoleTimeFrame; // Trame D: 0xff 0x0e ...
  final bool isConsolePaused;
  final int? cadenceSpm;
  final double? speedKmh;
  final int? powerWatts;
  final int? resistanceLevel;
  final double? distanceMeters;
  final double? caloriesKcal;
  final int? consoleStrokes;
  final int? consoleElapsedSeconds;
  final int? consolePauseSeconds;

  const DecodedProFormPacket({
    this.isStrokeVelocityFrame = false,
    this.isPowerDistanceFrame = false,
    this.isConsoleStrokesFrame = false,
    this.isConsoleTimeFrame = false,
    this.isConsolePaused = false,
    this.cadenceSpm,
    this.speedKmh,
    this.powerWatts,
    this.resistanceLevel,
    this.distanceMeters,
    this.caloriesKcal,
    this.consoleStrokes,
    this.consoleElapsedSeconds,
    this.consolePauseSeconds,
  });

  bool get isCadenceSpeedFrame => isStrokeVelocityFrame;
  bool get isWattsResistanceDistanceFrame => isPowerDistanceFrame;
  bool get isStrokesFrame => isConsoleStrokesFrame;
  bool get isElapsedTimeFrame => isConsoleTimeFrame;
  int? get watts => powerWatts;
  int? get strokesCount => consoleStrokes;
  int? get elapsedSeconds => consoleElapsedSeconds;
}

/// Implémentation pure du protocole binaire Pro-Form Sport RL (PFRW48121-INT.0 / BLE Name: I_RW)
class ProFormSportRLProtocol {
  static const String deviceAdvertisingPrefix = 'I_RW';
  static const String serviceUuid = '00001533-1412-efde-1523-785feabcd123';
  static const String writeCharUuid = '00001534-1412-efde-1523-785feabcd123';
  static const String notifyCharUuid = '00001535-1412-efde-1523-785feabcd123';

  static const List<int> unlockResistanceCommand = [0xfe, 0x02, 0x0d, 0x02];

  /// Séquence complète d'initialisation (btinit) combinant l'activation des registres
  /// télémétriques (issue #1498 I_RW) et la table spécifique du Pro-Form Sport RL
  static const List<List<int>> initSequenceSportRL = [
    // initData1
    [0xfe, 0x02, 0x08, 0x02],
    // initData2
    [
      0xff, 0x08, 0x02, 0x04, 0x02, 0x04, 0x02, 0x04, 0x81, 0x87,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ],
    // initData1
    [0xfe, 0x02, 0x08, 0x02],
    // initData3
    [
      0xff, 0x08, 0x02, 0x04, 0x02, 0x04, 0x14, 0x04, 0x80, 0x98,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ],
    // initData1
    [0xfe, 0x02, 0x08, 0x02],
    // initData4
    [
      0xff, 0x08, 0x02, 0x04, 0x02, 0x04, 0x14, 0x04, 0x88, 0xa0,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ],
    // initData5
    [0xfe, 0x02, 0x0a, 0x02],
    // initData6
    [
      0xff, 0x0a, 0x02, 0x04, 0x02, 0x06, 0x02, 0x06, 0x82, 0x00,
      0x00, 0x8a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ],
    // initData5
    [0xfe, 0x02, 0x0a, 0x02],
    // initData7
    [
      0xff, 0x0a, 0x02, 0x04, 0x02, 0x06, 0x02, 0x06, 0x84, 0x00,
      0x00, 0x8c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ],
    // initData1
    [0xfe, 0x02, 0x08, 0x02],
    // initData8
    [
      0xff, 0x08, 0x02, 0x04, 0x02, 0x04, 0x02, 0x04, 0x95, 0x9b,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ],
    // initData9 + initData10..12 standard I_RW (active les notifications télémétriques)
    [0xfe, 0x02, 0x2c, 0x04],
    [
      0x00, 0x12, 0x02, 0x04, 0x02, 0x28, 0x14, 0x28, 0x90, 0x07,
      0x01, 0xed, 0xe8, 0xe9, 0xe8, 0xf5, 0xf0, 0x09, 0x00, 0x1d
    ],
    [
      0x01, 0x12, 0x28, 0x39, 0x48, 0x55, 0x60, 0x99, 0xb0, 0xad,
      0xc8, 0xe9, 0x08, 0x55, 0x70, 0x89, 0xa0, 0xfd, 0x08, 0x59
    ],
    [
      0xff, 0x08, 0x68, 0xb5, 0xc0, 0x98, 0x02, 0x00, 0x00, 0x55,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ],
    // initData9 + initData10..12_proform_rower_sport_rl
    [0xfe, 0x02, 0x2c, 0x04],
    [
      0x00, 0x12, 0x02, 0x04, 0x02, 0x28, 0x14, 0x28, 0x90, 0x07,
      0x01, 0xf2, 0xf4, 0xf4, 0xf2, 0xfe, 0x08, 0x00, 0x1e, 0x2a
    ],
    [
      0x01, 0x12, 0x3c, 0x4c, 0x5a, 0x66, 0x90, 0x88, 0xa6, 0xc2,
      0xe4, 0x04, 0x22, 0x4e, 0x98, 0xb0, 0xce, 0x1a, 0x2c, 0x7c
    ],
    [
      0xff, 0x08, 0x8a, 0xd6, 0x20, 0x98, 0x02, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ],
    // Séquence finale d'amorçage du flux (noOpData4, 2, 3, 4, 5, 6, 1, 7_rl, 8_rl, 1, 2, 3)
    [0xfe, 0x02, 0x17, 0x03],
    [
      0x00, 0x12, 0x02, 0x04, 0x02, 0x15, 0x14, 0x15, 0x02, 0x00,
      0x0f, 0x00, 0x10, 0x00, 0xc0, 0x1c, 0x4c, 0x00, 0x00, 0xe0
    ],
    [
      0xff, 0x07, 0x00, 0x00, 0x00, 0x10, 0x00, 0x08, 0x6a, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ],
    [0xfe, 0x02, 0x17, 0x03],
    [
      0x00, 0x12, 0x02, 0x04, 0x02, 0x13, 0x14, 0x13, 0x02, 0x0c,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ],
    [
      0xff, 0x05, 0x00, 0x80, 0x01, 0x00, 0xb6, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ],
    [0xfe, 0x02, 0x19, 0x03],
    [
      0x00, 0x12, 0x02, 0x04, 0x02, 0x15, 0x14, 0x15, 0x02, 0x0e,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ],
    [
      0xff, 0x07, 0x00, 0x00, 0x00, 0x10, 0x01, 0x00, 0x4a, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ],
    [0xfe, 0x02, 0x19, 0x03],
    [
      0x00, 0x12, 0x02, 0x04, 0x02, 0x15, 0x14, 0x15, 0x02, 0x00,
      0x0f, 0x00, 0x10, 0x00, 0xc0, 0x1c, 0x4c, 0x00, 0x00, 0xe0
    ],
    [
      0xff, 0x07, 0x00, 0x00, 0x00, 0x10, 0x00, 0x08, 0x6a, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ],
  ];

  /// Cycle de 6 trames de maintien (Keep-Alive Polling séquentiel sans perte de paquets)
  /// Bloc 1 (indices 0,1,2) -> déclenche la réponse 0x00 0x12 (Watts, Distance, Résistance)
  /// Bloc 2 (indices 3,4,5) -> déclenche la réponse 0xff 0x11 (Cadence SPM, Vitesse)
  static const List<List<int>> pollingSequence = [
    // Poll 0 (noOpData1)
    [0xfe, 0x02, 0x17, 0x03],
    // Poll 1 (noOpData2)
    [
      0x00, 0x12, 0x02, 0x04, 0x02, 0x13, 0x14, 0x13, 0x02, 0x00,
      0x0d, 0x1c, 0x9e, 0x31, 0x00, 0x00, 0x40, 0x40, 0x00, 0x80
    ],
    // Poll 2 (noOpData3)
    [
      0xff, 0x05, 0x00, 0x00, 0x00, 0x81, 0xa2, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ],
    // Poll 3 (noOpData4 - l'injection de la résistance se fait juste avant ce paquet)
    [0xfe, 0x02, 0x19, 0x03],
    // Poll 4 (noOpData5)
    [
      0x00, 0x12, 0x02, 0x04, 0x02, 0x15, 0x14, 0x15, 0x02, 0x00,
      0x0f, 0x80, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ],
    // Poll 5 (noOpData6)
    [
      0xff, 0x07, 0x00, 0x00, 0x00, 0x00, 0xe0, 0x11, 0xeb, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ],
  ];

  /// Table des 24 niveaux de résistance SMR spécifiques au Pro-Form Sport RL (index 0 = Niveau 1)
  static const List<List<int>> sportRLResistanceTable = [
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0x76, 0x01, 0x00, 0x9b, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0x17, 0x03, 0x00, 0x3e, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0xb8, 0x04, 0x00, 0xe0, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0x58, 0x06, 0x00, 0x82, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0xf9, 0x07, 0x00, 0x24, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0x9a, 0x09, 0x00, 0xc7, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0x3a, 0x0b, 0x00, 0x69, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0xdb, 0x0c, 0x00, 0x0b, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0x7c, 0x0e, 0x00, 0xae, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0x1c, 0x10, 0x00, 0x50, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0xbd, 0x11, 0x00, 0xf2, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0x5e, 0x13, 0x00, 0x95, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0xfe, 0x14, 0x00, 0x36, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0x9f, 0x16, 0x00, 0xd9, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0x40, 0x18, 0x00, 0x7c, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0xe0, 0x19, 0x00, 0x1d, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0x81, 0x1b, 0x00, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0x22, 0x1d, 0x00, 0x63, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0xc2, 0x1e, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0x63, 0x20, 0x00, 0xa7, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0x04, 0x22, 0x00, 0x4a, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0xa4, 0x23, 0x00, 0xeb, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0x45, 0x25, 0x00, 0x8e, 0x00, 0x00, 0x00, 0x00, 0x00],
    [0xff, 0x0d, 0x02, 0x04, 0x02, 0x09, 0x14, 0x09, 0x02, 0x01, 0x04, 0xe6, 0x26, 0x00, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00],
  ];

  /// Retourne la trame de 20 octets pour régler la résistance entre 1 et 24
  static List<int> getResistanceFrame(int level) {
    final clamped = level.clamp(1, 24);
    return sportRLResistanceTable[clamped - 1];
  }

  /// Convertit l'octet [11] de la trame télémétrique en niveau de résistance 1..24
  static int decodeResistanceByte(int byte11) {
    switch (byte11 & 0xFF) {
      case 0x00:
      case 0x01:
        return 1;
      case 0x02:
      case 0x03:
        return 2;
      case 0x04:
      case 0x05:
        return 3;
      case 0x06:
        return 4;
      case 0x07:
      case 0x08:
        return 5;
      case 0x09:
      case 0x0a:
        return 6;
      case 0x0b:
        return 7;
      case 0x0c:
      case 0x0d:
        return 8;
      case 0x0e:
      case 0x0f:
        return 9;
      case 0x10:
        return 10;
      case 0x11:
      case 0x12:
        return 11;
      case 0x13:
        return 12;
      case 0x14:
      case 0x15:
        return 13;
      case 0x16:
      case 0x17:
        return 14;
      case 0x18:
        return 15;
      case 0x19:
      case 0x1a:
        return 16;
      case 0x1b:
      case 0x1c:
        return 17;
      case 0x1d:
        return 18;
      case 0x1e:
      case 0x1f:
        return 19;
      case 0x20:
      case 0x21:
        return 20;
      case 0x22:
        return 21;
      case 0x23:
      case 0x24:
        return 22;
      case 0x25:
        return 23;
      case 0x26:
      case 0x27:
        return 24;
      default:
        return 1;
    }
  }

  static List<List<int>> get resistanceCommands => sportRLResistanceTable;
  static int decodeResistanceFromTelemetryByte(int byte11) =>
      decodeResistanceByte(byte11);

  /// Encode l'octet [11] à partir d'un niveau 1..24 (utilisé par les tests unitaires)
  static int encodeResistanceByte(int level) {
    const map = [
      0x01, 0x03, 0x04, 0x06, 0x07, 0x09, 0x0b, 0x0c,
      0x0e, 0x10, 0x11, 0x13, 0x14, 0x16, 0x18, 0x19,
      0x1b, 0x1d, 0x1e, 0x20, 0x22, 0x23, 0x25, 0x26,
    ];
    return map[level.clamp(1, 24) - 1];
  }

  /// Décode une trame de notification de 20 octets provenant de la caractéristique 0x1535
  static DecodedProFormPacket? decodeTelemetryPacket(List<int> packet) {
    if (packet.length < 16) return null;

    final b0 = packet[0] & 0xFF;
    final b1 = packet[1] & 0xFF;
    final b2 = packet[2] & 0xFF;
    final b3 = packet[3] & 0xFF;
    final b4 = packet[4] & 0xFF;
    final b5 = packet[5] & 0xFF;

    // 1. Trame A : 0xff 0x11 ... (Cadence SPM, Vitesse et Coups de rame réels console)
    // Ignore uniquement la trame d'init "ff 11 01 04 02 0d ..."
    if (b0 == 0xff && b1 == 0x11) {
      if (b2 == 0x01 && b3 == 0x04) {
        return null; // Trame d'écho init
      }
      final cadence = packet[12] & 0xFF;
      final s = ((packet[14] & 0xFF) << 8) | (packet[13] & 0xFF);
      if (cadence > 90) {
        return null; // Valeur parasite hors plage aviron
      }
      final speedKmh = (cadence > 0 && s > 0) ? (60.0 / s) * 30.0 : 0.0;

      // Octets 10-11 : Coups de rame réels affichés sur la console LCD (3, 4, 5, ..., 8 coups)
      int? strokes;
      if (packet.length >= 12) {
        final rawStrokes = ((packet[11] & 0xFF) << 8) | (packet[10] & 0xFF);
        if (rawStrokes > 0 && rawStrokes < 60000) {
          strokes = rawStrokes;
        }
      }

      return DecodedProFormPacket(
        isStrokeVelocityFrame: true,
        cadenceSpm: cadence,
        speedKmh: speedKmh.clamp(0.0, 35.0),
        consoleStrokes: strokes,
      );
    }

    // 2. Trame B : 0x00 0x12 0x01 0x04 0x02 ... (Puissance Watts, Résistance SMR, Distance, Calories)
    if (b0 == 0x00 && b1 == 0x12 && b2 == 0x01 && b3 == 0x04 && b4 == 0x02) {
      if (packet.length < 16) return null;
      final b8 = packet[8] & 0xFF;
      // Ignore les réponses d'initialisation (où b8 vaut 0x80..0x95)
      if (b8 >= 0x80) return null;

      // Ignore la trame de remplissage 0x1f où les octets 12..15 valent tous 0xFF
      if ((packet[12] & 0xFF) == 0xFF &&
          (packet[13] & 0xFF) == 0xFF &&
          (packet[14] & 0xFF) == 0xFF &&
          (packet[15] & 0xFF) == 0xFF) {
        return null;
      }

      // Rejette strictement les trames de réponse handshake d'init (où b5 == 0x20)
      // Les trames télémétriques de travail ont b5 == 0x2e, 0x30 ou 0x31 ;
      // b10..b11 encode la résistance (ex: 00 00 pour SMR 1, c0 09 pour SMR 6).
      final isValidTelemetry =
          (b5 == 0x2e || b5 == 0x30 || b5 == 0x31);

      if (isValidTelemetry) {
        final resistance = decodeResistanceByte(packet[11] & 0xFF);
        final rawWatts = ((packet[13] & 0xFF) << 8) | (packet[12] & 0xFF);
        final watts = (rawWatts >= 60000 || rawWatts == 0xFFFF) ? 0 : rawWatts;

        final rawDistance = ((packet[15] & 0xFF) << 8) | (packet[14] & 0xFF);
        // Le Pro-Form Sport RL transmet 0xFFFF en sentinelle et 0x0000 à l'arrêt :
        // Ces valeurs ne doivent JAMAIS écraser la distance accumulée.
        final isPauseDist = rawDistance >= 60000 ||
            rawDistance == 0xFFFF ||
            ((packet[14] & 0xFF) == 0xFF && (packet[15] & 0xFF) == 0xFF);
        final double? distanceMeters =
            (isPauseDist || rawDistance == 0) ? null : rawDistance.toDouble();

        // Les calories proviennent exclusivement de la trame 0xff 0x0e
        return DecodedProFormPacket(
          isPowerDistanceFrame: true,
          powerWatts: watts.clamp(0, 1500),
          resistanceLevel: resistance,
          distanceMeters: distanceMeters,
          caloriesKcal: null,
          isConsolePaused: isPauseDist,
        );
      }
    }

    // 3. Trame C : 0x01 0x12 ... (Coups de rame cumulés sur la console LCD)
    // Télémétrie active: b0=0x01, b1=0x12, b2=0x00, b3=0x00, b4=0x01 (actif) ou 0x03 (pause)
    // Rejette strictement les trames de réponse handshake init où b3 != 0x00 (ex: 01 12 00 76 e8 2d ...)
    if (b0 == 0x01 && b1 == 0x12) {
      if (packet.length >= 7 && b2 == 0x00 && b3 == 0x00) {
        final strokes = ((packet[6] & 0xFF) << 8) | (packet[5] & 0xFF);
        if (strokes < 60000 && strokes != 0xFFFF) {
          final isPaused = (b4 == 0x03);
          return DecodedProFormPacket(
            isConsoleStrokesFrame: true,
            consoleStrokes: strokes,
            isConsolePaused: isPaused,
          );
        }
      }
    }

    // 4. Trame D : 0xff 0x0e ... (Temps écoulé, durée de pause et calories de la console LCD)
    if (b0 == 0xff && b1 == 0x0e) {
      // Rejette les trames de version ASCII firmware où b4 est du texte ASCII (ex: 0x32 '2')
      if (packet.length >= 13 && (b4 == 0x2c || b4 == 0x00)) {
        // Octets 2-3 : Calories cumulées (rejette 0 pour éviter d'écraser les calories lors de la pause console)
        final rawCalories = ((packet[3] & 0xFF) << 8) | (packet[2] & 0xFF);
        final double? calories =
            (rawCalories > 0 && rawCalories < 60000 && rawCalories != 0xFFFF)
                ? rawCalories.toDouble()
                : null;

        // Octets 6-7 : Temps écoulé effectif de travail (en secondes)
        final rawElapsed67 = ((packet[7] & 0xFF) << 8) | (packet[6] & 0xFF);

        // Octets 11-12 : Temps cumulé de pause console (en secondes) ou temps de travail sur ancien firmware.
        // Attention : cette valeur reste figée à son cumul après reprise (ex: 112s) et ne signifie pas "en pause" à elle seule.
        final rawTime1112 = ((packet[12] & 0xFF) << 8) | (packet[11] & 0xFF);

        int? elapsedSec;
        int? pauseSec;

        if (rawElapsed67 > 0 && rawElapsed67 < 60000) {
          elapsedSec = rawElapsed67;
          if (rawTime1112 > 0 && rawTime1112 < 60000) {
            pauseSec = rawTime1112;
          }
        } else if (rawTime1112 < 60000 && rawTime1112 != 0xFFFF) {
          // Repli sur octets 11-12 si octets 6-7 non renseignés (cas de tests unitaires synthétiques)
          elapsedSec = rawTime1112;
        }

        return DecodedProFormPacket(
          isConsoleTimeFrame: true,
          consoleElapsedSeconds: elapsedSec,
          consolePauseSeconds: pauseSec,
          caloriesKcal: calories,
          isConsolePaused: false,
        );
      }
    }

    return null;
  }

  /// Formate une liste d'octets en chaîne hexadécimale lisible
  static String toHex(List<int> bytes) =>
      bytes.map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0')).join(' ');
}

/// Service Bluetooth Low Energy (BLE) pour le rameur Pro-Form Sport RL (PFRW48121-INT.0 / I_RW)
class ProFormBleService extends ChangeNotifier {
  RowerTelemetry _telemetry = const RowerTelemetry();
  RowerTelemetry get telemetry => _telemetry;
  RowerTelemetry get latestTelemetry => _telemetry;
  bool get isHardwareConnected => _telemetry.isConnected;

  String? _lastError;
  String? get lastError => _lastError;

  final List<String> _bleLogs = [];
  List<String> get bleLogs => List.unmodifiable(_bleLogs);
  List<String> get protocolLogs => List.unmodifiable(_bleLogs);

  final List<ScanResult> _discoveredDevices = [];
  List<ScanResult> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  bool _pollingActive = false;
  int? _requestedResistance;
  DateTime _lastPacketTime = DateTime.now();
  double _sessionCalories = 0.0;
  double _activeUserWeightKg = 75.0;
  bool _liveSessionActive = false;
  bool _isHandshaking = false;
  int _rxPacketsCount = 0;
  int _lastConsolePauseSeconds = 0;

  void updateActiveUserWeight(double weightKg) {
    _activeUserWeightKg = weightKg > 30 ? weightKg : 75.0;
  }

  void setLiveSessionActive(bool active) {
    _liveSessionActive = active;
    if (active) {
      _sessionCalories = 0.0;
      _telemetry = _telemetry.copyWith(
        clearConsoleUnsynced: true,
      );
      notifyListeners();
    }
  }

  void _addLog(String message) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${(now.millisecond ~/ 10).toString().padLeft(2, '0')}';
    final line = '[$timeStr] $message';
    debugPrint('PROFORM_BLE $line');
    _bleLogs.insert(0, line);
    if (_bleLogs.length > 600) {
      _bleLogs.removeLast();
    }
  }

  void clearLogs() {
    _bleLogs.clear();
    notifyListeners();
  }

  String getFormattedLogsForExport() {
    if (_bleLogs.isEmpty) return 'Aucun log BLE enregistré pour l\'instant.';
    return _bleLogs.reversed.join('\n');
  }

  /// Lance un scan BLE à la recherche du rameur Pro-Form Sport RL (I_RW ou Service 0x1533)
  Future<void> startBleScan() async {
    if (_isScanning) return;
    _discoveredDevices.clear();
    _isScanning = true;
    _addLog('Scan BLE démarré (recherche de "I_RW" / 0x1533)...');
    notifyListeners();

    final foundIrwCompleter = Completer<void>();

    try {
      await _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          final name = r.device.platformName.isNotEmpty
              ? r.device.platformName
              : r.advertisementData.advName;
          final hasService = r.advertisementData.serviceUuids.any(
            (u) =>
                u.toString().toLowerCase() ==
                ProFormSportRLProtocol.serviceUuid,
          );
          final isProForm = name
                  .toUpperCase()
                  .startsWith(ProFormSportRLProtocol.deviceAdvertisingPrefix) ||
              name.toUpperCase().contains('PROFORM') ||
              name.toUpperCase().contains('IFIT') ||
              hasService;

          if (isProForm || name.isNotEmpty) {
            final idx = _discoveredDevices.indexWhere(
              (d) => d.device.remoteId == r.device.remoteId,
            );
            if (idx >= 0) {
              _discoveredDevices[idx] = r;
            } else {
              _discoveredDevices.add(r);
              if (name.toUpperCase().startsWith('I_RW') || hasService) {
                _addLog('Rameur détecté : $name (${r.device.remoteId})');
              }
            }
            if ((name.toUpperCase().startsWith('I_RW') || hasService) &&
                !foundIrwCompleter.isCompleted) {
              foundIrwCompleter.complete();
            }
          }
        }
        // Place les appareils I_RW en tête de liste
        _discoveredDevices.sort((a, b) {
          final nameA = (a.device.platformName.isNotEmpty
                  ? a.device.platformName
                  : a.advertisementData.advName)
              .toUpperCase();
          final nameB = (b.device.platformName.isNotEmpty
                  ? b.device.platformName
                  : b.advertisementData.advName)
              .toUpperCase();
          final aIrw = nameA.startsWith('I_RW') ? 0 : 1;
          final bIrw = nameB.startsWith('I_RW') ? 0 : 1;
          return aIrw.compareTo(bIrw);
        });
        notifyListeners();
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 6),
      );

      // Attend soit la détection immédiate de I_RW, soit la fin du délai de 6s
      await Future.any([
        foundIrwCompleter.future,
        Future.delayed(const Duration(seconds: 6)),
      ]);
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    } catch (e) {
      _addLog('Erreur Scan BLE : $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Connexion au rameur Pro-Form Sport RL (I_RW)
  Future<void> connectToDevice(BluetoothDevice device) async {
    await disconnect();
    final name = device.platformName.isNotEmpty
        ? device.platformName
        : 'I_RW (Pro-Form Sport RL)';
    final totalInitSteps = ProFormSportRLProtocol.initSequenceSportRL.length;

    _rxPacketsCount = 0;
    _lastConsolePauseSeconds = 0;
    _telemetry = RowerTelemetry(
      isConnected: false,
      isInitializing: true,
      initStepProgress: 0,
      initStepTotal: totalInitSteps,
      deviceName: name,
      deviceId: device.remoteId.str,
    );
    _addLog('Connexion à $name (${device.remoteId.str})...');
    notifyListeners();

    try {
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 12),
      );
      _connectedDevice = device;

      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _addLog('Déconnecté du rameur $name');
          disconnect();
        }
      });

      final services = await device.discoverServices();
      BluetoothService? proformService;
      for (final s in services) {
        if (s.uuid.toString().toLowerCase() ==
            ProFormSportRLProtocol.serviceUuid) {
          proformService = s;
          break;
        }
      }

      if (proformService == null) {
        throw Exception(
          'Service GATT 0x1533 introuvable sur cet appareil.',
        );
      }

      for (final c in proformService.characteristics) {
        final uuid = c.uuid.toString().toLowerCase();
        if (uuid == ProFormSportRLProtocol.writeCharUuid) {
          _writeCharacteristic = c;
        } else if (uuid == ProFormSportRLProtocol.notifyCharUuid) {
          _notifyCharacteristic = c;
        }
      }

      if (_writeCharacteristic == null || _notifyCharacteristic == null) {
        throw Exception(
          'Caractéristiques 0x1534 (Write) / 0x1535 (Notify) introuvables.',
        );
      }

      // 1. Abonnement au flux de notifications AVANT setNotifyValue(true)
      await _notifySubscription?.cancel();
      _isHandshaking = true;
      _notifySubscription =
          _notifyCharacteristic!.onValueReceived.listen(_onRawPacketReceived);
      await _notifyCharacteristic!.setNotifyValue(true);
      _addLog('Notifications activées sur 0x1535 (CCCD 0x0100)');

      // 2. Exécution séquentielle du handshake btinit (espacée de 350ms)
      _addLog('Envoi du handshake Pro-Form Sport RL ($totalInitSteps trames)...');
      for (int i = 0; i < totalInitSteps; i++) {
        if (_connectedDevice == null) {
          _isHandshaking = false;
          return;
        }
        _telemetry = _telemetry.copyWith(initStepProgress: i + 1);
        notifyListeners();
        final frame = ProFormSportRLProtocol.initSequenceSportRL[i];
        await _writePacketSequential(frame, label: 'init[${i + 1}/$totalInitSteps]');
        await Future.delayed(const Duration(milliseconds: 350));
      }

      _isHandshaking = false;
      _telemetry = _telemetry.copyWith(
        isConnected: true,
        isInitializing: false,
      );
      _addLog('Handshake terminé ! Démarrage du polling télémétrique séquentiel.');
      notifyListeners();

      // 3. Démarrage de la boucle de polling séquentielle (sans perte de paquets)
      _pollingActive = true;
      unawaited(_runSequentialPollingLoop());
    } catch (e) {
      _addLog('Erreur connexion BLE : $e');
      await disconnect();
    }
  }

  /// Écriture séquentielle garantie (attend la fin de l'écriture GATT avant de rendre la main)
  Future<void> _writePacketSequential(
    List<int> data, {
    String label = 'cmd',
    bool logPacket = true,
  }) async {
    final c = _writeCharacteristic;
    if (c == null || _connectedDevice == null) return;
    try {
      final useWithoutResponse =
          c.properties.writeWithoutResponse && !c.properties.write;
      await c
          .write(data, withoutResponse: useWithoutResponse)
          .timeout(const Duration(milliseconds: 600));
      if (logPacket) {
        _addLog('>> ${ProFormSportRLProtocol.toHex(data)} // $label');
      }
    } catch (e) {
      // Repli si le mode d'écriture préféré échoue
      try {
        await c
            .write(data, withoutResponse: true)
            .timeout(const Duration(milliseconds: 400));
      } catch (_) {}
    }
  }

  /// Boucle de polling séquentielle garantissant que les séquences de 3 paquets
  /// (noOpData 1->2->3 et noOpData 4->5->6) ne sont JAMAIS tronquées
  Future<void> _runSequentialPollingLoop() async {
    int step = 0;
    while (_pollingActive && _connectedDevice != null) {
      // Sur le Pro-Form Sport RL, l'injection de la résistance se fait juste avant l'étape 3
      if (step == 3 && _requestedResistance != null) {
        final target = _requestedResistance!;
        _requestedResistance = null;
        if (target >= 1 && target <= 24) {
          await _writePacketSequential(
            ProFormSportRLProtocol.unlockResistanceCommand,
            label: 'unlock_res',
          );
          await Future.delayed(const Duration(milliseconds: 120));
          final resFrame = ProFormSportRLProtocol.getResistanceFrame(target);
          await _writePacketSequential(
            resFrame,
            label: 'resistance_$target',
          );
          await Future.delayed(const Duration(milliseconds: 180));
        }
      }

      if (!_pollingActive || _connectedDevice == null) break;

      final pollFrame = ProFormSportRLProtocol.pollingSequence[step];
      await _writePacketSequential(
        pollFrame,
        label: 'poll[$step]',
        logPacket: false,
      );

      step = (step + 1) % 6;
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  /// Réception et décodage de chaque trame arrivant sur 0x1535
  void _onRawPacketReceived(List<int> bytes) {
    if (bytes.isEmpty) return;

    if (_isHandshaking) {
      _addLog('<< ${ProFormSportRLProtocol.toHex(bytes)}');
      return;
    }

    final now = DateTime.now();
    final dtSeconds =
        now.difference(_lastPacketTime).inMilliseconds.clamp(20, 5000) / 1000.0;
    _lastPacketTime = now;
    _rxPacketsCount++;

    final decoded = ProFormSportRLProtocol.decodeTelemetryPacket(bytes);

    if (decoded == null) {
      // Journalise les trames brutes non-télémétriques (ex: accusés de réception fe 02 ...)
      _addLog('<< ${ProFormSportRLProtocol.toHex(bytes)}');
      _telemetry = _telemetry.copyWith(rxPacketsCount: _rxPacketsCount);
      notifyListeners();
      return;
    }

    if (decoded.isStrokeVelocityFrame) {
      final spm = decoded.cadenceSpm ?? _telemetry.cadenceSpm;
      final speed = decoded.speedKmh ?? _telemetry.speedKmh;
      final strokes = (decoded.consoleStrokes != null && decoded.consoleStrokes! > 0)
          ? max(_telemetry.strokesCount, decoded.consoleStrokes!)
          : _telemetry.strokesCount;
      _addLog(
        '<< ${ProFormSportRLProtocol.toHex(bytes)} // Cadence: $spm SPM | Vitesse: ${speed.toStringAsFixed(1)} km/h | Coups: $strokes',
      );
      _telemetry = _telemetry.copyWith(
        cadenceSpm: spm,
        speedKmh: speed,
        strokesCount: strokes,
        rxPacketsCount: _rxPacketsCount,
        isConsolePaused: spm > 0 ? false : _telemetry.isConsolePaused,
      );
      notifyListeners();
      return;
    }

    if (decoded.isPowerDistanceFrame) {
      final watts = decoded.powerWatts ?? _telemetry.powerWatts;
      final res = decoded.resistanceLevel ?? _telemetry.resistanceLevel;
      // Rejette strictement les distances sentinelles (>= 60000m) et conserve la valeur max accumulée
      final dist = (decoded.distanceMeters != null &&
              decoded.distanceMeters! < 60000 &&
              decoded.distanceMeters! > 0)
          ? max(_telemetry.distanceMeters, decoded.distanceMeters!)
          : _telemetry.distanceMeters;

      // Calories calculées selon la puissance (Watts) et le poids de l'utilisateur
      // (la trame console ff 0e surestime d'environ 1.47x par rapport à la réalité)
      if (watts > 0) {
        _sessionCalories +=
            (((0.048 * watts + 1.19) * _activeUserWeightKg * 3.5) / 200.0) *
                (dtSeconds / 60.0);
      }
      final double calories = _sessionCalories;

      // Si la vitesse issue de ff 11 est à 0 mais que Watts > 0, calcule une vitesse réaliste depuis les Watts
      double effectiveSpeed = _telemetry.speedKmh;
      if (watts > 5 && effectiveSpeed <= 0.5) {
        // Formule physique Concept2 : v (m/s) = (watts / 2.80)^(1/3) -> * 3.6 km/h
        double g = 1.5;
        final ratio = watts / 2.80;
        for (int i = 0; i < 10; i++) {
          g = (2.0 * g + ratio / (g * g)) / 3.0;
        }
        effectiveSpeed = (g * 3.6).clamp(3.0, 28.0);
      } else if (watts == 0 && _telemetry.cadenceSpm == 0) {
        effectiveSpeed = 0.0;
      }

      double? unsyncedConsoleMeters = _telemetry.consoleDetectedUnsyncedMeters;
      if (!_liveSessionActive && dist >= 50.0 && dist < 60000 && unsyncedConsoleMeters == null) {
        unsyncedConsoleMeters = dist;
        _addLog(
          'Séance détectée sur la console LCD (${dist.toInt()} m) disponible pour synchronisation.',
        );
      }

      _addLog(
        '<< ${ProFormSportRLProtocol.toHex(bytes)} // ${watts}W | SMR $res/24 | ${dist.toInt()}m | ${calories.toInt()}kcal',
      );

      _telemetry = _telemetry.copyWith(
        powerWatts: watts,
        resistanceLevel: res,
        pendingTargetResistance: _requestedResistance,
        distanceMeters: dist,
        speedKmh: effectiveSpeed,
        caloriesKcal: calories,
        rxPacketsCount: _rxPacketsCount,
        consoleDetectedUnsyncedMeters: unsyncedConsoleMeters,
        isConsolePaused: decoded.isConsolePaused,
      );
      notifyListeners();
      return;
    }

    if (decoded.isConsoleStrokesFrame && decoded.consoleStrokes != null) {
      final consoleElapsedSec = decoded.consoleStrokes!;
      if (consoleElapsedSec > 0 && consoleElapsedSec < 60000) {
        // La trame 01 12 (octets 5-6) fournit la durée (ou minuteur) sur la console.
        final bool isTimeChanging =
            consoleElapsedSec != _telemetry.elapsedSeconds;
        _addLog(
          '<< ${ProFormSportRLProtocol.toHex(bytes)} // Console Durée (01 12): ${consoleElapsedSec}s${decoded.isConsolePaused ? " (En pause)" : ""}',
        );
        _telemetry = _telemetry.copyWith(
          elapsedSeconds: consoleElapsedSec,
          rxPacketsCount: _rxPacketsCount,
          isConsolePaused: decoded.isConsolePaused
              ? true
              : (isTimeChanging ? false : _telemetry.isConsolePaused),
        );
        notifyListeners();
      }
      return;
    }

    if (decoded.isConsoleTimeFrame) {
      final elapsedSec = decoded.consoleElapsedSeconds;
      final cal = decoded.caloriesKcal;
      final pauseSec = decoded.consolePauseSeconds;

      // packet[11..12] est le cumul de pause : la console n'est en pause que si ce compteur progresse.
      // La reprise est détectée par la trame 01 12 (b4 != 0x03 ou progression de la durée).
      final bool isActivelyCountingPause =
          pauseSec != null && pauseSec > _lastConsolePauseSeconds;
      if (pauseSec != null && pauseSec > _lastConsolePauseSeconds) {
        _lastConsolePauseSeconds = pauseSec;
      }
      final bool updatedPaused =
          isActivelyCountingPause ? true : _telemetry.isConsolePaused;

      final parts = <String>[];
      if (elapsedSec != null) parts.add('Console Durée: ${elapsedSec}s');
      if (cal != null) parts.add('Calories console (brut): ${cal.round()} kcal');
      if (pauseSec != null && pauseSec > 0) {
        parts.add('Pause cumulée: ${pauseSec}s${isActivelyCountingPause ? " (En pause)" : ""}');
      }
      _addLog('<< ${ProFormSportRLProtocol.toHex(bytes)} // ${parts.join(" | ")}');

      _telemetry = _telemetry.copyWith(
        elapsedSeconds: _telemetry.elapsedSeconds > 0
            ? _telemetry.elapsedSeconds
            : (elapsedSec ?? 0),
        rxPacketsCount: _rxPacketsCount,
        isConsolePaused: updatedPaused,
      );
      notifyListeners();
      return;
    }
  }

  /// Envoie une consigne de changement de résistance (1 à 24 SMR) au rameur
  Future<void> setResistanceLevel(int level, {String reason = 'Manuel'}) async {
    final target = level.clamp(1, 24);
    _requestedResistance = target;
    _telemetry = _telemetry.copyWith(
      resistanceLevel: target,
      pendingTargetResistance: target,
    );
    _addLog('Consigne résistance demandée : SMR $target/24 ($reason)');
    notifyListeners();
  }

  /// Scanne et se connecte automatiquement au rameur Pro-Form Sport RL (I_RW)
  Future<void> scanAndConnectHardware() async {
    _lastError = null;
    _telemetry = _telemetry.copyWith(
      isInitializing: true,
      deviceName: 'Recherche de I_RW...',
    );
    notifyListeners();

    await startBleScan();

    // Cherche en priorité l'appareil I_RW ou exposant le service 0x1533
    ScanResult? matched;
    for (final r in _discoveredDevices) {
      final name = (r.device.platformName.isNotEmpty
              ? r.device.platformName
              : r.advertisementData.advName)
          .toUpperCase();
      final hasService = r.advertisementData.serviceUuids.any(
        (u) =>
            u.toString().toLowerCase() == ProFormSportRLProtocol.serviceUuid,
      );
      if (name.startsWith('I_RW') ||
          name.contains('PROFORM') ||
          hasService) {
        matched = r;
        break;
      }
    }

    if (matched != null) {
      await connectToDevice(matched.device);
    } else {
      _lastError =
          'Aucun rameur I_RW détecté. Vérifiez que l\'écran du rameur est allumé et que le Bluetooth est actif.';
      _telemetry = _telemetry.copyWith(
        isInitializing: false,
        deviceName: 'Non connecté',
      );
      notifyListeners();
    }
  }

  /// Relance la séquence d'initialisation (15 trames) pour débloquer les capteurs
  Future<void> reinitializeHandshake() async {
    if (_connectedDevice == null || _writeCharacteristic == null) return;
    _pollingActive = false;
    _isHandshaking = true;
    await Future.delayed(const Duration(milliseconds: 250));

    final totalInitSteps = ProFormSportRLProtocol.initSequenceSportRL.length;
    _telemetry = _telemetry.copyWith(
      isInitializing: true,
      initStepProgress: 0,
      initStepTotal: totalInitSteps,
    );
    notifyListeners();

    for (int i = 0; i < totalInitSteps; i++) {
      if (_connectedDevice == null) {
        _isHandshaking = false;
        return;
      }
      _telemetry = _telemetry.copyWith(initStepProgress: i + 1);
      notifyListeners();
      final frame = ProFormSportRLProtocol.initSequenceSportRL[i];
      await _writePacketSequential(
        frame,
        label: 'reinit[${i + 1}/$totalInitSteps]',
      );
      await Future.delayed(const Duration(milliseconds: 350));
    }

    _isHandshaking = false;
    _telemetry = _telemetry.copyWith(
      isConnected: true,
      isInitializing: false,
    );
    notifyListeners();

    _pollingActive = true;
    unawaited(_runSequentialPollingLoop());
  }

  Future<void> disconnectHardware() => disconnect();

  Future<RowerTelemetry> readConsoleSummarySnapshot() async => _telemetry;

  void clearConsoleLateSyncFlag() {
    _telemetry = _telemetry.copyWith(clearConsoleUnsynced: true);
    notifyListeners();
  }

  Future<void> disconnect() async {
    _pollingActive = false;
    _isHandshaking = false;
    _liveSessionActive = false;
    await _notifySubscription?.cancel();
    _notifySubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    try {
      await _connectedDevice?.disconnect();
    } catch (_) {}
    _connectedDevice = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    _telemetry = const RowerTelemetry();
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingActive = false;
    _scanSubscription?.cancel();
    _notifySubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }
}
