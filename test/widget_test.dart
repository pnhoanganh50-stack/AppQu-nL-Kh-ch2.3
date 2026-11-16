import 'package:flutter_test/flutter_test.dart';
import 'package:quan_ly_khach/utils.dart';

void main() {
  test('Tìm kiếm không dấu', () {
    expect(normalize('Nguyễn Văn Đức'), 'nguyen van duc');
    expect(digitsOnly('090 123-4567'), '0901234567');
  });
}
