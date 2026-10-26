// Patterns no built-in example may match. words.test.ts checks the whole
// dataset against them, and scripts/claude-review-words.mjs checks each
// suggested correction before it is applied.

export const metaPatterns = [
  /\bthe word\b/i,
  /\bthe meaning of\b/i,
  /\bsimple (sentence|example)\b/i,
  /\blearner/i,
  /\bcan show how\b/i,
  /\bpractical context\b/i,
  /\bmeaning clearer\b/i,
  /\bcomplete sentence\b/i,
  /\blong definition\b/i,
  /\bfamiliar idea\b/i,
];

export const awkwardPatterns = [
  /A note about [a-z]+ helped/i,
  /The report mentioned [a-z]+ before/i,
  /became important after/i,
  /pointed [a-z]+ the main entrance/i,
  /with a clear [a-z]+ during/i,
  /關於.+的筆記/,
  /標誌指向與.+相關/,
  /幫助處理/,
  /用清楚的.+於/,
];

export const highRiskPatterns = [
  /\bexplained the [a-z]+ after the (meeting|lesson|interview|workshop|trip|review|practice|discussion|training|visit|trial|festival|inspection|presentation|debate|rehearsal)\b/i,
  /\btreated the [a-z]+ as important\b/i,
  /\bwas easy to find in the\b/i,
  /\bnoticed an? [a-z]+ detail in the\b/i,
  /\bhelped us [a-z]+ the next step\b/i,
  /\bPlease [a-z]+ the (plan|report|schedule|project|message|lesson|file|room|budget|map|letter|ticket|device|garden|contract|display) carefully\b/i,
  /在.+後說明了/,
  /視為重要/,
  /裡很容易找到/,
  /幫助我們.+下一步/,
];

export const broadTemplatePatterns = [
  /\bpeople remembered the moment because it changed the plan\b/i,
  /\bsomeone asked a follow-up question a few minutes later\b/i,
  /\bthe cook made one final adjustment before serving it\b/i,
  /\bthe answer was not obvious at first\b/i,
  /\bthe situation changed unexpectedly\b/i,
  /\bthe example showed when someone might need to\b/i,
  /人們記得那一刻，因為它改變了計畫/u,
  /幾分鐘後有人提出了追問/u,
  /廚師在上菜前做了最後一次調整/u,
  /答案一開始並不明顯/u,
  /情況意外改變/u,
  /\bsaved the [a-z]+ for the final\b/i,
  /\bstudied [a-z]+ during the\b/i,
  /\bbecame a sign of the season\b/i,
  /\bwaited beside the [a-z]+ after\b/i,
  /\bmade [a-z]+ easier to discuss\b/i,
  /^The [a-z]+ changed after the (meeting|lesson|interview|workshop|trip|review|practice|discussion|training|visit|trial|festival|inspection|presentation|debate|rehearsal)\b/i,
  /\breached the office before\b/i,
  /\banswered questions after the\b/i,
  /\blearned how to [a-z]+ it after\b/i,
  /\bphotographed the [a-z]+ at sunrise\b/i,
  /\bannounced a new (room|display|budget|contract|garden|device|ticket|file|lesson|project|plan)\b/i,
  /把那段.+留給最後/,
  /在.+中學習/,
  /成了.+附近的季節象徵/,
  /在.+後於.+旁等待/,
  /讓.+在.+前更容易被討論/,
];

export const genericFramePatterns = [
  /\bnoticed an? [a-z]+ part of the\b/i,
  /\bfound the [a-z]+ case difficult to explain\b/i,
  /\bAn? [a-z]+ result changed the [a-z]+ before\b/i,
  /\basked (briefly|carefully|clearly|openly|quietly|together) about [a-z]+ during the\b/i,
  /\btalked (briefly|carefully|clearly|openly|quietly|together) about [a-z]+ during the\b/i,
];

export const semanticMismatchPatterns = [
  /\bvisited the visit\b/i,
  /\bThe road to the (drop|lift)\b/i,
  /\bThe (pattern|schedule) began to (attend|submit)\b/i,
  /\bThe answer sounded clearer neither\b/i,
  /\bShe moved admittedly through\b/i,
  /\bThe [a-z]+ will prosper a new\b/i,
  /\bThe kitchen smelled of (parasite|butcher|brandy)\b/i,
  /\bThe (brandy|butcher) tasted fresh after\b/i,
  /\bThe (forty|thirty|twenty|fifteen|twelve|ten|nine|eight|seven|six|five|four|three|two) answer was\b/i,
  /\bThe (size|essence|log) (felt smooth|stood out)\b/i,
  /\bA (glowing|vibrant) (choice|question)\b/i,
  /\b[Aa] [a-z]+ color made\b/i,
  /\bShe chose an? [a-z]+ option before\b/i,
  /\bThe [a-z]+ detail stood out\b/i,
  /\bThe [a-z]+ design caught\b/i,
  /\bThe [a-z]+ stood out in the (ticket|plan)\b/i,
  /\bThe answer sounded clearer\b/i,
  /\bThe message changed slightly after\b/i,
  /\bThe sentence felt natural with\b/i,
  /\bThe team used [a-z]+ to connect\b/i,
  /\bHe listened particularly\b/i,
  /\banswered extremely\b/i,
  /\bworked plainly through\b/i,
  /\battend the schedule\b/i,
  /\bmarry the project\b/i,
  /\bThe drink tasted fresh\b/i,
  /\bStudents explored artist\b/i,
  /鑰匙在.+在(之上|下面|裡面|外面|以內|後面)/,
];

export const core1TemplatePatterns = [
  /\bincludes an? [a-z]+ for the\b/i,
  /\bclear example of [a-z]+ during\b/i,
  /\bchanged its plan before\b/i,
  /\basked about [a-z]+ before\b/i,
  /\bcontacted the [a-z]+ after\b/i,
  /\bShe gave an? [a-z]+ (answer|question|route|pattern|method) before\b/i,
  /\bThe [a-z]+ rule helped\b/i,
  /\bAn? [a-z]+ choice changed\b/i,
  /\bThe [a-z]+ will (let|lose|remove|imagine|withdraw) before\b/i,
  /\bWe discussed [a-z]+ in the .* before\b/i,
  /\bconnected [a-z]+ with daily life\b/i,
  /\bbegan to [a-z]+ during\b/i,
  /\bThe [a-z]+ (schedule|record|signal|habit|example|design) was easy to notice\b/i,
  /\brepaired the [a-z]+ before\b/i,
  /\bchecked the (year|day|thought|rise) before\b/i,
  /\bThe bus may (think|fail)\b/i,
  /\bThe (people|staff|security) answered questions after\b/i,
  /\bA map near .* marked the (give|wall)\b/i,
  /\bThe very meeting\b/i,
  /\bmade thing easier to discuss\b/i,
  /\btell the room\b/i,
  /\btable was made of drug\b/i,
  /\bhospital made the discussion difficult\b/i,
  /\bsaved the season\b/i,
  /\bclearer (soon|rather) the final edit\b/i,
  /\baccept the room after\b/i,
  /\btrade changed after the rehearsal\b/i,
  /\bA central room gave us space\b/i,
  /\bwaited beside the stage\b/i,
  /\bseek the message after\b/i,
  /\bfuture passed faster\b/i,
  /\bchose film for the new design\b/i,
  /\bplant became a sign of the season near the schedule\b/i,
  /\breduce the oil before\b/i,
  /\bA small claim changed the final price\b/i,
  /\bwith herself in the middle\b/i,
  /\beconomy covered the cost of the room\b/i,
  /\bwest changed after the review\b/i,
  /\bThe near road\b/i,
  /\bphotographed the east at sunrise\b/i,
  /\bmade design easier to discuss\b/i,
];

export const badSensePattern =
  /白痴|不介意|辯論的|醫生的|獨立自主者的|人的部分|特效藥|對手的案例|奇數的部分|字首的部分|牙科醫生的風險|外科醫生的風險|有勢力的人的部分/;

/** The first rule an example breaks, or null. `group` is the word's level, such as "Core 1". */
export function exampleRuleProblem({ word, example, exampleZh, group }) {
  const text = `${example} ${exampleZh}`;
  const lists = [
    ['meta-learning wording', metaPatterns],
    ['awkward scaffolding', awkwardPatterns],
    ['high-risk generic frame', highRiskPatterns],
    ['stitched template', broadTemplatePatterns],
    ['generic frame', genericFramePatterns],
    ['semantic mismatch', semanticMismatchPatterns],
    ...(group === 'Core 1' ? [['Core 1 template', core1TemplatePatterns]] : []),
  ];
  for (const [rule, patterns] of lists) {
    if (patterns.some((pattern) => pattern.test(text))) return rule;
  }
  if (/^[a-z]/.test(example)) return 'example starts with a lowercase letter';
  if (/的的/.test(exampleZh)) return 'repeated 的';
  if (badSensePattern.test(exampleZh)) return 'dictionary sense leakage';
  if (/[\u4e00-\u9fff]/.test(example)) return 'Chinese in the English example';
  return null;
}
