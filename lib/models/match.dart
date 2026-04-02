import 'package:flutter/material.dart';

class Match {
  final String date;
  final String time;
  final String location;
  final String league;
  final String homeAway; // 主場 or 客場
  final String opponent;
  final int? jerseyColorValue;

  Match({
    required this.date,
    required this.time,
    required this.location,
    required this.league,
    required this.homeAway,
    required this.opponent,
    Color? jerseyColor,
  }) : jerseyColorValue = jerseyColor?.toARGB32();

  Color? get jerseyColor => jerseyColorValue != null ? Color(jerseyColorValue!) : null;

  Map<String, dynamic> toJson() => {
    'date': date,
    'time': time,
    'location': location,
    'league': league,
    'homeAway': homeAway,
    'opponent': opponent,
    'jerseyColor': jerseyColorValue,
  };

  factory Match.fromJson(Map<String, dynamic> json) => Match(
    date: json['date'] ?? '',
    time: json['time'] ?? '',
    location: json['location'] ?? '',
    league: json['league'] ?? '',
    homeAway: json['homeAway'] ?? '',
    opponent: json['opponent'] ?? '',
    jerseyColor: json['jerseyColor'] != null ? Color(json['jerseyColor']) : null,
  );

  Match copyWith({
    String? date,
    String? time,
    String? location,
    String? league,
    String? homeAway,
    String? opponent,
    Color? jerseyColor,
  }) {
    return Match(
      date: date ?? this.date,
      time: time ?? this.time,
      location: location ?? this.location,
      league: league ?? this.league,
      homeAway: homeAway ?? this.homeAway,
      opponent: opponent ?? this.opponent,
      jerseyColor: jerseyColor ?? this.jerseyColor,
    );
  }
}