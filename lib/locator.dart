import 'package:get_it/get_it.dart';

import 'repositories/user_repository.dart';
import 'repositories/group_repository.dart';
import 'repositories/meetup_repository.dart';
import 'repositories/place_search_repository.dart';

final locator = GetIt.instance;

void setupLocator() {
  locator.registerLazySingleton<UserRepository>(() => UserRepository());
  locator.registerLazySingleton<GroupRepository>(() => GroupRepository());
  locator.registerLazySingleton<PlaceSearchRepository>(
    () => PlaceSearchRepository(),
  );
  locator.registerLazySingleton<MeetupRepository>(() => MeetupRepository());
}
