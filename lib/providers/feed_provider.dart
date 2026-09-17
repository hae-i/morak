import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/meetup_model.dart';
import '../locator.dart';
import '../repositories/meetup_repository.dart';

final feedProvider = FutureProvider<List<MeetupModel>>((ref) async {
  final repo = locator<MeetupRepository>();
  return await repo.fetchHomeFeeds();
});
