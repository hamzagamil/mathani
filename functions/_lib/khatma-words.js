// Words not allowed in group khatma names and titles (specs/014 FR-060, research R19). Kept by the
// owner: a web deploy changes them, with no app release. Compared after normalising
// (khatma-text.js): Arabic marks and tatweel removed, alef, hamza, yaa and taa marbuta forms
// unified, Latin letters lower-cased. Write entries already normalised.

/** Matched as whole words only, so ordinary names that contain them are not refused. */
export const wholeWords = [
  // English
  'ass', 'arse', 'bastard', 'bitch', 'bollocks', 'cock', 'cunt', 'dick', 'dyke', 'fag', 'faggot',
  'fuck', 'fucker', 'fucking', 'motherfucker', 'nigga', 'nigger', 'piss', 'prick', 'pussy',
  'retard', 'shit', 'slut', 'twat', 'wank', 'wanker', 'whore', 'porn', 'sex', 'sexy', 'nazi',
  'hitler', 'kill', 'rape', 'rapist', 'terrorist', 'isis',
  // Arabic
  'كلب', 'حمار', 'خنزير', 'حيوان', 'غبي', 'اهبل', 'حقير', 'وسخ', 'زباله', 'قذر', 'تافه', 'منحط',
  'كافر', 'زنديق', 'ملحد', 'داعش', 'ارهابي', 'قحبه', 'شرموطه', 'عاهره', 'زانيه', 'زاني', 'منيوك',
  'متناك', 'نيك', 'خول', 'لوطي', 'ديوث', 'معرص', 'عرص', 'كس', 'زب', 'طيز', 'سكس', 'اباحي',
];

/** Matched anywhere, also inside longer words. */
export const anywhere = [
  // English
  // Not "shit" or "cunt" here: they sit inside ordinary names and places (Ashita, Scunthorpe).
  'fuck', 'nigger', 'nigga', 'faggot', 'motherf', 'bitch', 'whore', 'pussy', 'porn', 'rapist',
  // Arabic
  'شرموط', 'قحب', 'منيوك', 'متناك', 'عاهر', 'معرص', 'ديوث', 'كسمك', 'كس ام', 'ابن الكلب',
  'ابن كلب', 'يلعن', 'ابن الحرام', 'ابن حرام', 'ابن الزنا', 'خنزير', 'سكس', 'اباحي',
];
