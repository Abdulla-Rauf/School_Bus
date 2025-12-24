// lib/screens/calendar/setup/utils/calculation_utils.dart


import '../../../../../models/calendar_model.dart';

class CalculationUtils {
  static double calculateWorkingDaysPercentage(List<WorkingDay> workingDays) {
    int workingDaysCount = workingDays.where((day) => day.isWorkingDay).length;
    return (workingDaysCount / 7) * 100;
  }

  static Map<String, int> calculateAcademicYearStats({
    required DateTime startDate,
    required DateTime endDate,
    required List<WorkingDay> workingDays,
  }) {
    int totalDays = endDate.difference(startDate).inDays + 1;
    int workingDaysCount = 0;
    int holidayCount = 0;

    DateTime current = startDate;
    for (int i = 0; i < totalDays; i++) {
      int dayOfWeek = current.weekday;
      WorkingDay? workingDay = workingDays.firstWhere(
            (day) => day.dayOfWeek == dayOfWeek,
        orElse: () => WorkingDay(dayOfWeek: dayOfWeek, isWorkingDay: false),
      );

      if (workingDay.isWorkingDay) {
        workingDaysCount++;
      } else {
        holidayCount++;
      }
      current = current.add(const Duration(days: 1));
    }

    return {
      'totalDays': totalDays,
      'workingDays': workingDaysCount,
      'holidays': holidayCount,
    };
  }
}