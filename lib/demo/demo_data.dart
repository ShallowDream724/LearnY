import 'package:intl/intl.dart';

import '../core/api/enums.dart';
import '../core/api/models.dart' as api;

/// One shared fixture powers bootstrap and subsequent API syncs.
class DemoData {
  DemoData({DateTime? now}) : now = now ?? DateTime.now() {
    final year = this.now.month >= 8 ? this.now.year : this.now.year - 1;
    final term = this.now.month >= 8 || this.now.month <= 1 ? 1 : 2;
    semesters = [
      _semester(
        year,
        term,
        this.now.subtract(Duration(days: this.now.weekday - 1 + 21)),
      ),
      _semester(year - 1, 2, DateTime(year, 2, 23)),
      _semester(year - 1, 1, DateTime(year - 1, 9, 1)),
    ];
    for (
      var semesterIndex = 0;
      semesterIndex < semesters.length;
      semesterIndex++
    ) {
      final semester = semesters[semesterIndex];
      final names = semesterIndex == 0
          ? ['数据结构', '概率论与数理统计', '计算机系统', '学术英语']
          : semesterIndex == 1
          ? ['线性代数', '程序设计基础', '大学物理']
          : ['微积分', '计算机科学导论'];
      courses[semester.id] = [
        for (var index = 0; index < names.length; index++)
          api.CourseInfo(
            id: 'demo-${semester.id}-$index',
            name: names[index],
            chineseName: names[index],
            englishName: '',
            timeAndLocation: [
              '星期${['一', '二', '三', '四'][index]}第1-2节(1-16周),六教6A${201 + index}',
            ],
            url: '',
            teacherName: ['陈老师', '李老师', '王老师', '周老师'][index],
            teacherNumber: 'demo-teacher-$index',
            courseNumber: 'DEMO${100 + index}',
            courseIndex: index + 1,
            courseType: CourseType.student,
          ),
      ];
      for (final course in courses[semester.id]!) {
        final index = course.courseIndex - 1;
        final historical = semesterIndex != 0;
        homeworks[course.id] = [
          _homework(
            course,
            'review',
            '第${index + 2}章习题',
            deadline: this.now.add(Duration(hours: 8 + index * 20)),
            submitted: historical,
            graded: historical,
          ),
          _homework(
            course,
            'report',
            '实验报告：方法与结果分析',
            deadline: this.now.subtract(const Duration(days: 2)),
            submitted: true,
            graded: historical,
          ),
          _homework(
            course,
            'practice',
            '课堂练习与思考',
            deadline: this.now.subtract(const Duration(days: 7)),
            submitted: true,
            graded: true,
          ),
        ];
        notifications[course.id] = [
          api.Notification(
            id: '${course.id}-notice',
            title: index == 0 ? '本周答疑安排' : '课程资料与学习安排',
            content:
                '<p>本周课程资料已上传，请提前阅读相关章节。</p><p>答疑时间为周四下午 15:00 至 16:00，地点为六教 302。欢迎带着问题交流。</p>',
            hasRead: index.isOdd,
            url: '',
            markedImportant: index == 0,
            publishTime: timestamp(
              this.now.subtract(Duration(hours: 3 + index * 12)),
            ),
            publisher: course.teacherName,
            isFavorite: false,
          ),
        ];
        final fileId = '${course.id}-notes';
        final url = 'https://demo.learny.invalid/files/$fileId';
        final content =
            '${course.name}\n\n课程学习提纲\n\n一、回顾核心概念，整理课堂笔记。\n二、结合例题练习，记录解题思路。\n三、在答疑课讨论尚未解决的问题。\n';
        fileContents[fileId] = content;
        files[course.id] = [
          api.CourseFile(
            id: fileId,
            fileId: fileId,
            rawSize: content.length * 3,
            size: '1 KB',
            title: '${course.name}学习提纲.txt',
            description: '本周知识要点与课后练习安排。',
            uploadTime: timestamp(this.now.subtract(Duration(days: index + 1))),
            publishTime: timestamp(
              this.now.subtract(Duration(days: index + 1)),
            ),
            downloadUrl: url,
            previewUrl: '',
            isNew: index.isEven,
            markedImportant: index == 0,
            visitCount: 0,
            downloadCount: 0,
            fileType: 'txt',
            category: api.FileCategory(
              id: '${course.id}-materials',
              title: '课程资料',
              creationTime: timestamp(this.now),
            ),
            remoteFile: api.RemoteFile(
              id: fileId,
              name: '${course.name}学习提纲.txt',
              downloadUrl: url,
              previewUrl: '',
              size: '1 KB',
            ),
          ),
        ];
      }
    }
  }

  static const username = '林同学';
  final DateTime now;
  late final List<api.SemesterInfo> semesters;
  final courses = <String, List<api.CourseInfo>>{};
  final homeworks = <String, List<api.Homework>>{};
  final notifications = <String, List<api.Notification>>{};
  final files = <String, List<api.CourseFile>>{};
  final fileContents = <String, String>{};

  String get officialSemesterId => semesters.first.id;

  api.SemesterInfo _semester(int year, int term, DateTime start) =>
      api.SemesterInfo(
        id: '$year-${year + 1}-$term',
        startDate: dateKey(start),
        endDate: dateKey(start.add(const Duration(days: 126))),
        startYear: year,
        endYear: year + 1,
        type: term == 1 ? SemesterType.fall : SemesterType.spring,
      );

  api.Homework _homework(
    api.CourseInfo course,
    String suffix,
    String title, {
    required DateTime deadline,
    required bool submitted,
    required bool graded,
  }) => api.Homework(
    id: '${course.id}-$suffix',
    studentHomeworkId: '${course.id}-$suffix',
    baseId: '${course.id}-$suffix',
    title: title,
    deadline: timestamp(deadline),
    url: '',
    completionType: HomeworkCompletionType.individual,
    submissionType: HomeworkSubmissionType.webLearning,
    submitUrl: '',
    submitTime: submitted
        ? timestamp(deadline.subtract(const Duration(hours: 4)))
        : null,
    isLateSubmission: false,
    submitted: submitted,
    graded: graded,
    grade: graded ? 92 : null,
    gradeTime: graded ? timestamp(deadline.add(const Duration(days: 1))) : null,
    graderName: graded ? course.teacherName : null,
    gradeContent: graded ? '推导完整，结论清楚。请留意边界条件的说明。' : null,
    isFavorite: false,
    description: '<p>请结合本章内容完成题目，写出关键步骤，并说明使用的方法。</p><p>提交内容应包含过程、结果及简短总结。</p>',
    submittedContent: submitted ? '<p>已完成习题并整理推导过程，详见实验记录。</p>' : null,
  );

  static String timestamp(DateTime value) =>
      value.millisecondsSinceEpoch.toString();

  static String dateKey(DateTime value) =>
      DateFormat('yyyy-MM-dd').format(value);
}
