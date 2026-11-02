/// 2~4단계 기능을 앱에 붙이는 곳. 단계가 추가될 때마다 여기에 한 줄씩 늘어난다.
bool _registered = false;

void registerStages() {
  if (_registered) return;
  _registered = true;
}
