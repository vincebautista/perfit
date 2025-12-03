import 'package:flutter/material.dart';
import 'package:perfit/core/constants/colors.dart';
import 'package:perfit/core/constants/sizes.dart';
import 'package:perfit/widgets/text_styles.dart';

class RestDaySelectionScreen extends StatefulWidget {
  final int workoutDays;
  final List<String> selectedRestDays;

  const RestDaySelectionScreen({
    super.key,
    required this.workoutDays,
    required this.selectedRestDays,
  });

  @override
  State<RestDaySelectionScreen> createState() => _RestDaySelectionScreenState();
}

class _RestDaySelectionScreenState extends State<RestDaySelectionScreen> {
  late List<String> tempRestDays;

  final List<String> weekDays = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ];

  @override
  void initState() {
    super.initState();
    tempRestDays = [...widget.selectedRestDays];
  }

  @override
  Widget build(BuildContext context) {
    final int restCount = 7 - widget.workoutDays;

    return Scaffold(
      appBar: AppBar(
        title: Text("Select your $restCount rest day(s)"),
      ),
      body: Padding(
        padding: EdgeInsets.all(AppSizes.padding16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: weekDays.map((day) {
                  final selected = tempRestDays.contains(day);
                  return CheckboxListTile(
                    title: Text(day),
                    value: selected,
                    onChanged: (val) {
                      if (val == true) {
                        if (tempRestDays.length < restCount) {
                          setState(() => tempRestDays.add(day));
                        }
                      } else {
                        setState(() => tempRestDays.remove(day));
                      }
                    },
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: AppSizes.gap15),
            ElevatedButton(
              onPressed: tempRestDays.length == restCount
                  ? () {
                      Navigator.pop(context, tempRestDays);
                    }
                  : null,
              child: Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}
