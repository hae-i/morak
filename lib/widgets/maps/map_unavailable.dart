import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';

class MapUnavailable extends StatelessWidget {
  const MapUnavailable({super.key});
  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    padding: const EdgeInsets.all(20),
    color: AppConstants.scaffoldBackground,
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.map_outlined, color: AppConstants.primaryColor, size: 32),
        SizedBox(height: 12),
        Text('지금 지도를 표시할 수 없어요.', textAlign: TextAlign.center),
        SizedBox(height: 8),
        Text(
          '장소 이름과 주소로 기록을 확인할 수 있어요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppConstants.textBody, fontSize: 13),
        ),
      ],
    ),
  );
}
