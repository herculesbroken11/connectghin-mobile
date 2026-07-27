/// US state codes and display labels for forms (Post spot, location, etc.).
class UsState {
  const UsState(this.code, this.name);

  final String code;
  final String name;

  String get label => '$code — $name';
}

const kUsStates = <UsState>[
  UsState('AL', 'Alabama'),
  UsState('AK', 'Alaska'),
  UsState('AZ', 'Arizona'),
  UsState('AR', 'Arkansas'),
  UsState('CA', 'California'),
  UsState('CO', 'Colorado'),
  UsState('CT', 'Connecticut'),
  UsState('DE', 'Delaware'),
  UsState('DC', 'District of Columbia'),
  UsState('FL', 'Florida'),
  UsState('GA', 'Georgia'),
  UsState('HI', 'Hawaii'),
  UsState('ID', 'Idaho'),
  UsState('IL', 'Illinois'),
  UsState('IN', 'Indiana'),
  UsState('IA', 'Iowa'),
  UsState('KS', 'Kansas'),
  UsState('KY', 'Kentucky'),
  UsState('LA', 'Louisiana'),
  UsState('ME', 'Maine'),
  UsState('MD', 'Maryland'),
  UsState('MA', 'Massachusetts'),
  UsState('MI', 'Michigan'),
  UsState('MN', 'Minnesota'),
  UsState('MS', 'Mississippi'),
  UsState('MO', 'Missouri'),
  UsState('MT', 'Montana'),
  UsState('NE', 'Nebraska'),
  UsState('NV', 'Nevada'),
  UsState('NH', 'New Hampshire'),
  UsState('NJ', 'New Jersey'),
  UsState('NM', 'New Mexico'),
  UsState('NY', 'New York'),
  UsState('NC', 'North Carolina'),
  UsState('ND', 'North Dakota'),
  UsState('OH', 'Ohio'),
  UsState('OK', 'Oklahoma'),
  UsState('OR', 'Oregon'),
  UsState('PA', 'Pennsylvania'),
  UsState('RI', 'Rhode Island'),
  UsState('SC', 'South Carolina'),
  UsState('SD', 'South Dakota'),
  UsState('TN', 'Tennessee'),
  UsState('TX', 'Texas'),
  UsState('UT', 'Utah'),
  UsState('VT', 'Vermont'),
  UsState('VA', 'Virginia'),
  UsState('WA', 'Washington'),
  UsState('WV', 'West Virginia'),
  UsState('WI', 'Wisconsin'),
  UsState('WY', 'Wyoming'),
];
