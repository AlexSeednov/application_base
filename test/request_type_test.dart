import 'package:application_base/data/remote/const/request_duration_type.dart';
import 'package:application_base/data/remote/const/request_type.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';

/// An upload is the heavy request the long timeout exists for, so both upload
/// types take it unless the caller says otherwise; every other request keeps
/// the normal one.
void main() {
  test('uploads run with the long timeout by default', () {
    expect(
      RequestPostFormData(path: 'photo').durationType,
      RequestDurationType.long,
    );
    expect(
      RequestPostFile(path: 'photo', file: XFile('photo.jpg')).durationType,
      RequestDurationType.long,
    );
  });

  test('an upload takes the timeout its caller picks', () {
    expect(
      RequestPostFile(
        path: 'photo',
        file: XFile('photo.jpg'),
        durationType: RequestDurationType.normal,
      ).durationType,
      RequestDurationType.normal,
    );
  });

  test('other requests keep the normal timeout', () {
    expect(
      RequestGet(path: 'projects').durationType,
      RequestDurationType.normal,
    );
    expect(
      RequestPost(path: 'projects').durationType,
      RequestDurationType.normal,
    );
  });
}
