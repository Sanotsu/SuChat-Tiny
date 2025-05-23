// 自定义标签，常用来存英文、中文、全小写带下划线的英文等。
class CusLabel {
  final String? enLabel;
  final String cnLabel;
  final dynamic value;

  CusLabel({this.enLabel, required this.cnLabel, required this.value});

  @override
  String toString() {
    return '''
    CusLabel{
      enLabel: $enLabel, cnLabel: $cnLabel, value:$value
    }
    ''';
  }
}

// 时间格式化字符串
const constDatetimeFormat = "yyyy-MM-dd HH:mm:ss";
const constDateFormat = "yyyy-MM-dd";
const constMonthFormat = "yyyy-MM";
const constTimeFormat = "HH:mm:ss";
// 文件名后缀等
const constDatetimeSuffix = "yyyyMMdd_HHmmss";
// 未知的时间字符串
const unknownDateTimeString = '1970-01-01 00:00:00';
const unknownDateString = '1970-01-01';

const String placeholderImageUrl = 'assets/images/no_image.png';
