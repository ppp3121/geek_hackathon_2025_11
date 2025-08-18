import 'package:flutter/material.dart';
import 'category_selector.dart';
import 'facility_name_input.dart';
import 'search_button.dart';

class SearchConditionsPanel extends StatelessWidget {
  const SearchConditionsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16.0),
      child: const SingleChildScrollView(
        child: Column(
          children: [
            FacilityNameInput(),
            SizedBox(height: 16),
            CategorySelector(),
            SearchButton(),
          ],
        ),
      ),
    );
  }
}