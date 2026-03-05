/// Default SDUI vote form schema (v2) used when the server returns null.
///
/// Provides a minimal but representative comfort survey with thermal,
/// preference (with emoji), and air quality fields.
class DefaultVoteForm {
  DefaultVoteForm._();

  static Map<String, dynamic> get config => {
        'schemaVersion': 2,
        'formTitle': 'Comfort Vote',
        'formDescription':
            'Quick survey about your environment – takes under a minute.',
        'thanksMessage': 'Thanks for your feedback!',
        'allowAnonymous': false,
        'cooldownMinutes': 30,
        'fields': [
          {
            'key': 'thermal_comfort',
            'type': 'thermal_scale',
            'question': 'How hot or cold do you feel?',
            'min': 1,
            'max': 7,
            'defaultValue': 4,
            'labels': {
              '1': 'Cold',
              '2': 'Cool',
              '3': 'Slightly Cool',
              '4': 'Neutral',
              '5': 'Slightly Warm',
              '6': 'Warm',
              '7': 'Hot',
            },
          },
          {
            'key': 'thermal_preference',
            'type': 'single_select',
            'question': 'Do you want to be warmer or cooler?',
            'options': [
              {
                'label': 'Warmer',
                'value': 1,
                'color': 'orange',
                'emoji': '🔥'
              },
              {
                'label': 'I am good',
                'value': 2,
                'color': 'green',
                'emoji': '👍'
              },
              {
                'label': 'Cooler',
                'value': 3,
                'color': 'blue',
                'emoji': '❄️'
              },
            ],
          },
          {
            'key': 'air_quality',
            'type': 'multi_select',
            'question': 'What do you think about the air quality?',
            'options': [
              {
                'label': 'Suffocating',
                'value': 'suffocating',
                'emoji': '😤'
              },
              {'label': 'Humid', 'value': 'humid', 'emoji': '💧'},
              {'label': 'Dry', 'value': 'dry', 'emoji': '🏜️'},
              {'label': 'Smelly', 'value': 'smelly', 'emoji': '🤢'},
              {
                'label': 'All good!',
                'value': 'all_good',
                'exclusive': true,
                'color': 'green',
                'emoji': '✅',
              },
            ],
          },
        ],
      };
}
