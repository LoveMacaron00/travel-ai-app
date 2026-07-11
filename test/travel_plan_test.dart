import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/model/travel_plan.dart';

void main() {
  test('parses a location-aware AI travel plan', () {
    final plan = TravelPlan.fromJson({
      'summary': 'A compact Bangkok day',
      'totalEstimatedCost': 1250,
      'budgetBreakdown': {'transport': 300, 'activities': 500, 'food': 450},
      'days': [
        {
          'day': 1,
          'theme': 'Old town',
          'stops': [
            {
              'destinationId': 12,
              'place': 'Wat Pho',
              'activity': 'Visit the temple',
              'latitude': 13.7465,
              'longitude': 100.4930,
              'arrivalTime': '09:00',
              'durationMinutes': 90,
              'entryCost': 300,
              'foodCost': 100,
              'transportMode': 'car',
              'transportCost': 120,
              'segments': [
                {
                  'mode': 'car',
                  'from': 'hotel',
                  'to': 'Wat Pho',
                  'estimatedMinutes': 20,
                  'estimatedCost': 120,
                },
              ],
            },
          ],
        },
      ],
      'tips': ['Carry water'],
    }, tripId: 7);

    expect(plan.tripId, 7);
    expect(plan.allStops.single.place, 'Wat Pho');
    expect(plan.allStops.single.latitude, 13.7465);
    expect(plan.budgetBreakdown['transport'], 300);
    expect(plan.allStops.single.segments.single.estimatedMinutes, 20);
  });
}
